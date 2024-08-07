#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M HIER
# Put it in context
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::hier;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

  use Arstd::Bytes;
  use Arstd::IO;

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.7;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    name  => null,
    node  => undef,

    type  => 'blk',
    hist  => {},
    shist => [],

    used  => 0x00,
    vused => 0x00,
    moded => 0x00,

    var   => {
      -order => [],

    },

    loadmap => {},
    citer   => {},
    biter   => [],

    io    => {

      map {

        $ARG=>{

          bias => 0x00,
          used => 0x00,

          var  => {-order=>[]},

        },

      } qw  (in out)

    },

    stack => {-size=>0x00},

    mcid  => 0,
    mccls => null,

  },


  typetab => {
    proc  => [qw(const readable executable)],
    struc => [qw(const readable)],

  },

  blk_re => qr{struc|proc},

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  $class->defnit(\%O);

  my $self  = bless \%O,$class;
  my $flags = $class->typetab->{$self->{type}};

  $self->set_uattrs(

    (defined $flags)
      ? @$flags
      : ()
      ,

  );


  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};


  # calculate initial register allocation bias
  my $inbias=$anima->regmask(qw(
    ar br cr dr sp sb
    ice ctx opt chan

  ));

  my $outbias=$anima->regmask(qw(
    er fr gr hr xp xs

  ));


  $self->{io}->{in}->{bias}  |= $inbias;
  $self->{io}->{out}->{bias} |= $outbias;


  return $self;

};

# ---   *   ---   *   ---
# apply on-close logic
# invoked during solve step

sub ribbon($self) {


  # get method matching block type
  my $class = ref $self;

  my $fn    = "$class\::ribbon_$self->{type}";
     $fn    = \&$fn;

  # ^invoke if found, else do nothing
  $fn->($self)
  if defined $self;


  return;

};

# ---   *   ---   *   ---
# ^iceof

sub ribbon_struc($self) {


  # get ctx
  my $mc   = $self->getmc();
  my $main = $mc->get_main();

  my $ptr  = $self->{node}->{vref}->{res};


  # deanon ptr
  my ($name,$full,@path)=
    $mc->ptrid($ptr);


  # read structure fields
  my $inner = $ptr->get_node();
  my $src   = join ";\n",map {

    my $x=${$inner->get($ARG)};


    # give decl list
    my ($label) = $mc->ptrid($x);
    my $type    = $x->get_type();

    "$type->{name} $label";


  } @{$self->{var}->{-order}};


  # redefine existing!
  restruc $full,$src;
  return;

};

# ---   *   ---   *   ---
# run through block and generate any
# necessary additional instructions

sub expand($self) {

  $self->build_iter(1);
  $self->bindvars();
  $self->procblk();

  return;

};

# ---   *   ---   *   ---
# wraps: scope to this block

sub set_scope($self) {


  # get ctx
  my $mc   = $self->getmc();
  my $nd   = $self->{node};

  my $vref = $nd->{vref};


  # get full path into namespace
  my $blk=$vref->{res};
  my ($name,@path)=$blk->fullpath;

  # ^set as current
  $mc->scope(@path,$name);


  return;

};

# ---   *   ---   *   ---
# make/fetch point in hist

sub timeline($self,$uid,$data=undef) {

  # get ctx
  my $mc   = $self->getmc();
  my $hist = $self->{hist};

  # fetch, (set)?, give
  my $out = \$hist->{$uid};

  $$out=$mc->hierstruc($data)
  if defined $data;

  return $$out;

};

# ---   *   ---   *   ---
# decl input/output var

sub addio($self,$ins,$name) {


  # get ctx
  my $mc    = $self->getmc();
  my $main  = $mc->get_main();
  my $anima = $mc->{anima};


  # unpack
  my $key  = $ins;
     $ins  = 'out' if $key eq 'io';

  my $have = $self->{io}->{$ins};
  my $dst  = $have->{var};


  # validate input
  $main->perr(

    "redecl of [good]:%s var '%s'\n"
  . "for [ctl]:%s '%s'",

    args=>[
      $ins,$name,
      $self->{type},$self->{name}

    ],

  ) if exists $dst->{$name};


  # setup allocation bias
  my $bias = $have->{bias};
  my $old  = $anima->{almask};

  $anima->{almask}=$bias;


  # allocate register
  my $idex=$anima->alloci();

  $dst->{$name}={

    name        => $name,

    deps_for => [],
    decl     => -1,

    loc      => $idex,
    ptr      => undef,
    defv     => undef,
    bound    => undef,

    loaded   => $key ne 'out',

  };


  # update bias and restore
  my $bit = 1 << $idex;

  $have->{used}    |= $bit;
  $self->{vused}   |= $bit;
  $have->{bias}    |= $bit;
  $anima->{almask}  = $old;


  # edge case: output eq input
  if($key eq 'io') {

    my $alt=$self->{io}->{in};

    $alt->{var}->{$name}=$dst->{$name};
    push @{$alt->{var}->{-order}},$name;

  };


  # set and give
  push @{$dst->{-order}},$name;
  $self->{loadmap}->{$idex}=$dst->{$name};

  return;

};

# ---   *   ---   *   ---
# check existence of tmp value
# add if not found

sub chkvar($self,$name,$idex) {


  # skip on io var
  my $io=$self->{io};

  map {
    return $io->{$ARG}->{var}->{$name}
    if exists $io->{$ARG}->{var}->{$name};

  } qw(in out);


  # making new var?
  if(! exists $self->{var}->{$name}) {

    push @{$self->{var}->{-order}},$name;

    my $load=(! index $name,'%')
      ? 'const' : 0 ;

    $idex=0 if $load eq 'const';


    $self->{var}->{$name}={

      name     => $name,

      deps_for => [],
      decl     => $idex,

      loc      => undef,
      ptr      => undef,
      defv     => undef,
      bound    => undef,

      loaded   => $load,

    };


  # stepping on existing!
  } else {

    my $have=$self->{var}->{$name};

    $have->{decl}=$idex
    if $have->{decl} < 0;

  };


  return $self->{var}->{$name};

};

# ---   *   ---   *   ---
# fetch operand and register dependency

sub depvar($self,$var,$depname,$idex) {

  my $dep=$self->chkvar($depname,$idex);
  push @{$dep->{deps_for}},[$var->{name},$idex];

  return $dep;

};

# ---   *   ---   *   ---
# get value is overwritten at
# an specific timeline point

sub is_overwrite($self,$point) {

  return (

      $point->{overwrite}
  &&! $point->{load_dst}

  );

};

# ---   *   ---   *   ---
# get names of all existing values

sub varkeys($self,%O) {

  # defaults
  $O{io}     //= 0;
  $O{common} //= 1;

  # get lists of names
  my @out=($O{common})
    ? @{$self->{var}->{-order}}
    : ()
    ;


  # ^get io vars?
  push @out,map {
    @{$self->{io}->{$ARG}->{var}->{-order}};

  } ($O{io} eq 'all')
    ? qw(in out)
    : $O{io}

  if $O{io};


  return grep {! ($ARG=~ qr{^[\%\$]})} @out;

};

# ---   *   ---   *   ---
# sort nodes in history

sub sort_hist($self,$recalc=0) {


  # get ctx
  my $out = $self->{shist};
  my @uid = keys %{$self->{hist}};

  # skip if we don't need to recalculate
  my $ok=@$out == @uid;
  return $out if $ok &&! $recalc;


  # sort elements idex relative to root
  my $root = $self->{node};
  my @have = $root->find_uid(@uid);

  map {
    my $i=$ARG->relidex($root);
    $out->[$i]=$self->{hist}->{$ARG->{-uid}};

  } @have;


  # remove blanks and give
  @$out=grep {defined $ARG} @$out;
  return $out;

};

# ---   *   ---   *   ---
# makes room in stack for elem
# if elem if needed

sub chkstk($self,$vref) {


  # get ctx
  my $mc    = $self->getmc();
  my $stack = $mc->{stack};

  # skip?
  return if $stack->is_ptr($vref->{ptr});


  # grow stack and give
  $self->{stack}->{-size} +=
    $stack->repoint($vref->{ptr});

  # record position of elem
  $self->{stack}->{$vref->{name}}=
    $self->{stack}->{-size};


  return;

};

# ---   *   ---   *   ---
# manage register allocation
# to values within a block
#
# this includes spilling to stack

sub load($self,$dst,$which) {


  # get ctx
  my $mc    = $self->getmc();
  my $ISA   = $mc->{ISA};
  my $anima = $mc->{anima};
  my $stack = $mc->{stack};


  # output of this F is an
  # instruction list!
  my @out=();


  # have plain register?
  if(! index $dst->{name},'$') {

    $dst->{loc}=substr
      $dst->{name},1,
      (length $dst->{name})-1;

    return $self->chkuse($dst);

  };


  # need to allocate register?
  if(! defined $dst->{loc}) {


    # can we free anything?
    my $var=$self->{citer}->{var};

    map {
      $self->chkneed($var->{$ARG});

    } grep {

      my $x=$var->{$ARG};

       defined $x->{loc}
    && exists  $self->{loadmap}->{$x->{loc}};

    } $self->varkeys(io=>'in');


    # setup allocation bias
    my $io   = $self->{io};
    my $bias = $io->{out}->{used};
    my $old  = $anima->{almask};

    $bias |= $io->{in}->{used};
    $bias |= $self->{used};


    # get free register
    $anima->{almask}=$bias;
    my $idex = $anima->alloci();
    my $bit  = 1 << $idex;

    # ^mark in use and restore
    $self->{used}    |= $bit;
    $dst->{loc}       = $idex;

    $anima->{almask}  = $old;

  };


  # avoid unnecessary loads
  my $iter  = $self->{citer};
  my $point = $iter->{point};
  my $j     = $iter->{j};
  my $ins   = $point->{Q}->[$j]->[1];

  goto skip if ($dst->{loaded} || (

      $ins ne 'st'
  &&! $point->{"load_$which"}->[$j]

  ));


  # have constant value to load?
  if(defined $dst->{defv}) {

    my $x=$dst->{defv};

    push @out,[

      $dst->{ptr}->{type},
      'ld',

      {type=>'r',reg=>$dst->{loc}},
      {type=>$ISA->immsz($x),imm=>$x},

    ];


    $dst->{defv}=undef;


  # loading undefined?
  } elsif(! $stack->is_ptr($dst->{ptr})) {

    my $npres=(
      ($self->{vused})
    & (1 << $dst->{loc})

    );

    my $main=$mc->get_main();

    # * case 0: this value is uninitialized,
    #   and so we must throw

    $main->bperr(

      $self->{iter}->{point}->{branch},

      "attempt to use undefined value '%s'",
      args=>[$dst->{name}],


    # * case 1: value was initialized, but
    #   was simply not preserved, so noop
    ) if ! $npres;


  # ^nope, load from stack
  } else {

    $self->chkstk($dst);

    my $base = $stack->{base}->load();
    my $off  = $base-$dst->{ptr}->{addr};

    push @out,[

      $dst->{ptr}->{type},
      'ld',

      {type=>'r',reg=>$dst->{loc}},
      {type=>'mstk',imm=>$off},

    ];

  };


  # mark as loaded and give
  skip:

  $dst->{loaded}  = 1;
  $self->{vused} |= 1 << $dst->{loc};

  my $key=$dst->{loc};
  $self->{loadmap}->{$key}=$dst;


  return @out;

};

# ---   *   ---   *   ---
# check that value is no
# longer needed from this point
# onwards

sub chkneed($self,$vref) {

  $self->unload($vref)

  if ! $self->lookahead(
    qr{.+}=>\&la_reqvar,
    $vref

  );


  return;

};

# ---   *   ---   *   ---
# check that register is in use
# by another value
#
# if so, determine whether to
# spill or not

sub chkuse($self,$vref) {


  # output is instruction list
  my @out=();

  # get coords
  my $bit=1 << $vref->{loc};

  my $key=$vref->{loc};
  my $old=$self->{loadmap}->{$key};


  # we need first check whether
  # this value is required by a
  # future instruction

  if(defined $old) {


    # * case 0: required, so backup the
    #   value and let the load F restore
    #   it when that point is reached

    if($self->lookahead(
      qr{.+}=>\&la_reqvar,
      $old

    )) {
      push @out,$self->spill($old);


    # * case 1: not required, so simply
    #   overwrite the value without
    #   backing it up

    } else {
      $self->unload($old);

    };

  };


  # adjust masks and give
  $self->{vused} |= $bit;
  return @out;

};

# ---   *   ---   *   ---
# mark value as in use, but not
# currently in memory

sub unload($self,$vref) {


  # get ctx
  my $idex  = $vref->{loc};
  my $bit   = 1 << $idex;


  # remove value from memory table
  delete $self->{loadmap}->{$idex};

  # adjust masks
  my $io   =  $self->{io};
  my $nbit = ~$bit;

  # TODO: make this less messy
  $self->{used}      &= $nbit;
  $io->{out}->{used} &= $nbit;
  $io->{in}->{used}  &= $nbit;

  $vref->{loc}    = undef;
  $vref->{loaded} = 0;


  return;

};

# ---   *   ---   *   ---
# ^save to stack

sub spill($self,$vref) {


  # get ctx
  my $mc    = $self->getmc();
  my $stack = $mc->{stack};

  my $idex  = $vref->{loc};
  my $bit   = 1 << $idex;


  # make room in stack?
  $self->chkstk($vref);


  # get addr in stack
  my $base = $stack->{base}->load();

  my $off  = $vref->{ptr}->{addr};
     $off  = $base - $off;


  # generate store instruction
  my $out=[

    $vref->{ptr}->{type},
    'st',

    {type=>'mstk',imm=>$off},
    {type=>'r',reg=>$idex},

  ];


  # cleanup and give
  $self->unload($vref);
  return $out;

};

# ---   *   ---   *   ---
# get name of value

sub vname($self,$var) {


  # get ctx
  my $mc=$self->getmc();


  # have register?
  my $out=null;
  if($var->{type} eq 'r') {
    $out="\$$var->{reg}";

  # have alias?
  } else {

    $out = $var->{imm_args}->[0];
    $out = (! exists $out->{id})
      ? $var->{id}
      : $out->{id}
      ;


    if(defined $out) {

      my ($name,@path)=@$out;
      (@path)=$mc->local_deanonid(@path,$name);

      $out=join '::',@path;

    };

  };


  # have immediate!
  if(! defined $out) {
    $out="\%$var->{imm}";

  };


  return $out;

};

# ---   *   ---   *   ---
# begin new walk of block elements

sub reset_iter($self) {

  $self->{citer}={

    i     => 0,
    j     => 0,
    k     => 0,

    point => undef,
    dst   => undef,
    src   => undef,

    var   => {},
    match => undef,

    prog  => undef,
    nprog => undef,

  };

  return $self->{citer};

};

# ---   *   ---   *   ---
# ^save current

sub backup_iter($self) {

  my $iter=$self->{citer};
  my $back=$self->{biter};

  push @$back,[
    map {$iter->{$ARG}}
    qw  (i j k point match)

  ];


  return;

};

# ---   *   ---   *   ---
# ^load previous

sub restore_iter($self) {

  my $iter=$self->{citer};
  my $back=$self->{biter};

  my $have=pop @$back;

  map {$iter->{$ARG}=shift @$have}
  qw  (i j k point match);


  return;

};

# ---   *   ---   *   ---
# 'prog' is the list of instructions
# that make up a block
#
# an element within this list may be
# base or generated, meaning the input
# code itself or code spawned by this
# class' methods
#
# we need to mark each element as such,
# so that we can selectively choose to
# skip one or the other based on this
# distinction

sub prog_elem($self,$type,@args) {

  return [

    $type,

    $self->{citer}->{point},
    @args,

  ];

};

# ---   *   ---   *   ---
# walks through the current program,
# filtering entries accto type

sub prog_walk($self,$i,$type,$fn,@args) {


  # get ctx
  my $iter = $self->{citer};
  my $prog = $iter->{prog};

  # output is plain exit code
  my $status=0;


  # reset
  $iter->{i}     = $i;
  $iter->{j}     = 0;
  $iter->{point} = undef;

  # get sub-idex?
  if($i != 0) {

    my $j=1;
    my $p=$prog->[$i]->[1];

    $j++ while (

       ($i-$j > 0)
    && ($prog->[$i-$j] eq $p)

    );


    $iter->{j}     = $j-1;
    $iter->{point} = $p;

  };


  # apply F to filtered array
  my $limit=(int @$prog)-1;

  map {


    # get instruction
    my ($e,$newp,$dst,$src)=
      $self->timeline_step();

    $iter->{dst}=$dst;
    $iter->{src}=$src;


    # run F on matching type
    if($e=~ $type) {
      $status=$fn->($self,@args);
      return $status if $status != 0;

    };


    # go next
    $iter->{i}++;
    $iter->{j}++;


  } @{$prog}[$i..$limit];


  return $status;

};

# ---   *   ---   *   ---
# initial run-through of block
#
# this builds context from which
# it can be later analyzed

sub build_iter($self,$recalc=0) {


  # scope to this block
  $self->set_scope();


  # get block elements
  my $hist=$self->sort_hist($recalc);
  my $iter=$self->reset_iter();


  # ^walk
  $iter->{prog}=[map {

    $iter->{point}=$ARG;

    map {

      my @out=$self->get_ins($ARG);

      $iter->{i} += (int @out) != 0;
      @out;

    } @{$iter->{point}->{Q}};


  } @$hist];

  @{$iter->{nprog}}=@{$iter->{prog}};


  # check IO vars

  map {

    my $io  = $self->{io}->{$ARG};
    my $var = $io->{var};

    map {
      $iter->{var}->{$ARG}=$var->{$ARG};

    } @{$var->{-order}};


  } qw (in out);


  return;

};

# ---   *   ---   *   ---
# ^unpack individual instruction

sub get_ins($self,$data) {


  # get ins/operands
  my ($opsz,$ins,@args)=@$data;


  # data-decls aren't processed ;>
  return if $ins=~ qr{
    ^(?:(?:data|seg)\-decl|raw)$

  }x;

  # instructions without arguments
  # are all special cased
  return $self->argless_ins($ins)
  if ! @args;


  # ^else process normally
  my ($dst,$src)=$self->get_operands(
    $ins,@args

  );


  # write back to caller
  my $iter   = $self->{citer};
  my $argcnt = length $src->{name};

  $iter->{var}->{$dst->{name}}=$dst;
  $iter->{var}->{$src->{name}}=$src if $argcnt;


  # give synthesis
  return $self->prog_elem(

    base=>($argcnt)
      ? ($dst,$src)
      : ($dst)
      ,

  );

};

# ---   *   ---   *   ---
# handle argless instructions

sub argless_ins($self,$ins) {

  my $fn={
    int => \&linux_syscall,
    ret => \&push_argless,

  }->{$ins};

  return (defined $fn)
    ? $fn->($self) : () ;

};

# ---   *   ---   *   ---
# do nothing, but keep the instruction

sub push_argless($self) {
  return $self->prog_elem(base=>());

};

# ---   *   ---   *   ---
# edge case: linux syscalls!

sub linux_syscall($self) {


  # get ctx
  my $iter   = $self->{citer};
  my $point  = $iter->{point};
  my $branch = $point->{branch};
  my $vref   = $branch->{vref};

  my $pass   = $vref->{data}->{pass};
  my $code   = $vref->{data}->{code};
  my $j      = @$pass-1;


  # get syscall idex
  my $dst=$self->vname({type=>'r',reg=>0});
     $dst=$self->chkvar($dst,$iter->{i});

  # ^get values passed
  map {

    $self->depvar(
      $dst,
      $self->vname({type=>'r',reg=>$ARG}),

      $iter->{i}-$j--,

    );

  } @$pass;


  # we can safely ignore the next bit
  # on a sysexit, since overwritten registers
  # won't matter!

  goto skip if $code eq 'exit';


  # syscall parameters and return are
  # preserved automatically if they are in
  # use by the calling process
  #
  # all other registers, save for rcx/cr
  # and r11/chan, are preserved by the kernel
  #
  # this means we must mark the two exceptions
  # as *virtually* in use by the process,
  # meaning even if they are not used by this
  # block itself, they may still be overwritten
  # by the syscall
  #
  # this in turn informs a second process calling
  # this one that these exception registers
  # should be preserved *if* they are in use at
  # the time of the call

  my $mc    = $self->getmc();
  my $anima = $mc->{anima};

  my $mask  = $anima->regmask(qw(cr chan));

  $self->{vused} |= $mask;
  $self->{moded} |= $mask;


  # go next and give
  skip:

  $iter->{i}++;
  $dst->{-syscall}=$code;

  $iter->{point}->{Q}->[$iter->{j}]->[0]=
    typefet 'dword';

  return $self->prog_elem(base=>$dst);

};

# ---   *   ---   *   ---
# ^unpack instruction operands

sub get_operands($self,$ins,@args) {


  # get ctx
  my $mc    = $self->getmc();
  my $iter  = $self->{citer};

  my $ISA   = $mc->{ISA};
  my $meta  = $ISA->_get_ins_meta($ins);

  my $point = $iter->{point};


  # get destination
  my $var  = $point->{var};
  my $name = $self->vname($args[0]);

  push @$var,$name;
  my $dst=$self->chkvar($name,$iter->{i});

  # ^get source
  my $src={name=>null};

  if($args[1] && $meta->{overwrite}) {
    $name = $self->vname($args[1]);
    $src  = $self->depvar($dst,$name,$iter->{i});

  };


  return ($dst,$src);

};

# ---   *   ---   *   ---
# bind vars in block to memory references

sub bindvars($self) {


  # get ctx
  my $mc   = $self->getmc();
  my $iter = $self->{citer};


  # walk vars
  map {


    # locate dummy reference for
    # non-constant values
    my $dst=$iter->{var}->{$ARG};


    $dst->{ptr}=$mc->xpsearch($ARG)

    if ! defined $dst->{loaded}
    ||   $dst->{loaded} ne 'const';


    # ^found pointer?
    if(defined $dst->{ptr}) {
      $dst->{ptr}=${$dst->{ptr}};


      # ^pointer to block IS const
      if(

         exists $dst->{ptr}->{p3ptr}
      || $dst->{ptr}->is_rom()

      ) {

        $dst->{loaded} = 'const';
        $dst->{loc}    = undef;

      };

    };


  } $self->varkeys(io=>'all');


  return;

};

# ---   *   ---   *   ---
# process all timeline points

sub procblk($self) {


  # get ctx
  my $iter = $self->{citer};
  my $var  = $iter->{var};

  # backup IO locations
  my %io=map {
    $ARG=>$var->{$ARG}->{loc};

  } $self->varkeys(io=>'all',common=>0);


  # walk timeline
  $self->prog_walk(0=>qr{base}=>\&procins);

  # update program
  @{$iter->{prog}}=@{$iter->{nprog}};

  # does this block utilize the stack?
  if($self->{stack}->{-size}) {
    $self->stack_setup();
    $self->stack_cleanup();

  };


  # restore IO locations
  map {
    $var->{$ARG}->{loc}=$io{$ARG}

  } keys %io;


  return;

};

# ---   *   ---   *   ---
# ^process instruction in timeline point

sub procins($self) {


  # get ctx
  my $iter = $self->{citer};

  my $point = $iter->{point};
  my $dst   = $iter->{dst};
  my $src   = $iter->{src};


  # get instruction name
  my $j   = $iter->{j};
  my $ins = $point->{Q}->[$j]->[1];

  # have edge case?
  my $edgetab={
    bind => \&on_bind,
    pass => \&on_pass,
    call => \&on_call,

  };

  my $fn=$edgetab->{$ins};

  if(defined $fn) {

    my @ins=$fn->($self,$dst,$src);
    return 0 if @ins &&! $ins[0];

    $self->insert_ins(@ins);

  };


  # generate intermediate loads
  $self->ldvar($dst,'dst');
  $self->ldvar($src,'src');

  # perform operand replacements
  $iter->{k}=0;

  $self->replvar($dst);
  $self->replvar($src);


  return 0;

};

# ---   *   ---   *   ---
# get next instruction

sub timeline_step($self) {


  # get ctx
  my $iter  = $self->{citer};
  my $point = $iter->{point};
  my $prog  = $iter->{prog};
  my $data  = $prog->[$iter->{i}];


  # unpack
  my ($e,$newp,$dst,$src)=@$data;

  # stepping on new timeline point?
  if(! $point || $point ne $newp) {
    $iter->{point} = $newp;
    $iter->{j}     = 0;

  };


  return ($e,$newp,$dst,$src);

};

# ---   *   ---   *   ---
# put instruction array at pointer

sub insert_ins($self,@ins) {


  # get ctx
  my $iter  = $self->{citer};

  my $prog  = $iter->{prog};
  my $nprog = $iter->{nprog};
  my $point = $iter->{point};
  my $Q     = $point->{Q};

  my $i     = $iter->{i};
  my $j     = $iter->{j};


  $i += @$nprog-@$prog;


  # add fake markers for generated instructions
  #
  # this is done so that the generation can
  # be spotted -- and skipped -- in any
  # future iterations of this program

  @$nprog=(

    @{$nprog}[0..$i-1],

    (map {
      $self->prog_elem('generated')

    } @ins),

    @{$nprog}[$i..@$nprog-1],

  );


  # modify assembly queue
  @$Q=(
    @{$Q}[0..$j-1],
    @ins,
    @{$Q}[$j..@$Q-1],

  );


  # adjust point to match new dimentions
  my $have = int @ins;

  map {

    my $dst=$point->{$ARG};

    @$dst=(

      @{$dst}[0..$j-1],
      (map {undef} 0..$have-1),

      @{$dst}[$j..@$dst-1],

    );

  } grep {
    ! ($ARG=~ qr{^(?:Q|branch)$});

  } keys %$point;


  # ^move to end of generated
  $iter->{j} += $have;

  return;

};

# ---   *   ---   *   ---
# ^remove instruction at pointer!

sub remove_ins($self) {


  # get ctx
  my $iter  = $self->{citer};

  my $prog  = $iter->{prog};
  my $nprog = $iter->{nprog};
  my $point = $iter->{point};
  my $Q     = $point->{Q};

  my $i     = $iter->{i};
  my $j     = $iter->{j};


  $i += @$nprog-@$prog;


  # remove marker
  @$nprog=(
    @{$nprog}[0..$i-1],
    @{$nprog}[$i+1..@$nprog-1],

  );


  # modify assembly queue
  @$Q=(
    @{$Q}[0..$j-1],
    @{$Q}[$j+1..@$Q-1],

  );


  # adjust point to match new dimentions
  map {

    my $dst=$point->{$ARG};

    @$dst=(
      @{$dst}[0..$j-1],
      @{$dst}[$j+1..@$dst-1],

    );

  } grep {
    ! ($ARG=~ qr{^(?:Q|branch)$});

  } keys %$point;


  # ^move to previous
  $iter->{j} -= 1;

  return;

};

# ---   *   ---   *   ---
# grow the stack for this block

sub stack_setup($self) {


  # get ctx
  my $iter  = $self->{citer};
  my $prog  = $iter->{prog};

  my $mc    = $self->getmc();
  my $anima = $mc->{anima};
  my $ISA   = $mc->{ISA};

  my $qword = typefet 'qword';
  my $size  = $self->{stack}->{-size};


  # seek to beggining of program
  $iter->{point} = $prog->[0]->[1];
  $iter->{i}     = 0;
  $iter->{j}     = 0;

  # add equivalent of 'enter' instruction ;>
  $self->insert_ins(

    [ $qword,
      'push',
      {type=>'r',reg=>$anima->stack_base},

    ],

    [ $qword,
      'ld',

      {type=>'r',reg=>$anima->stack_base},
      {type=>'r',reg=>$anima->stack_ptr},

    ],

    [ $qword,
      'sub',

      {type=>'r',reg=>$anima->stack_ptr},
      {type=>$ISA->immsz($size),imm=>$size},

    ],

  );


  return;

};

# ---   *   ---   *   ---
# ^add cleanup for each ret

sub stack_cleanup($self) {

  # walk timeline
  $self->prog_walk(0=>qr{base}=>\&leave_per_ret);

  # clear and give
  my $mc=$self->getmc();
  $mc->{stack}->reset();

  return;

};

# ---   *   ---   *   ---
# prepend a leave to every ret

sub leave_per_ret($self) {


  # get ctx
  my $iter  = $self->{citer};
  my $point = $iter->{point};

  my $qword = typefet 'qword';


  # have a ret?
  my $j    = $iter->{j};
  my $Q    = $point->{Q};

  my $have = $Q->[$j];


  # ^add a leave instruction if so
  $self->insert_ins([$qword,'leave'])
  if $have->[1] eq 'ret';


  return 0;

};

# ---   *   ---   *   ---
# walk iter from current position
# and find mention of vref

sub lookahead($self,$re,$fn,$vref) {


  # save status of current iteration
  $self->backup_iter();


  # walk program from current ins onwards
  my @branch = ();
  my $out    = 0;
  my $beg    = $self->{citer}->{i};

  $self->prog_walk(

    $beg=>qr{base}=>\&la_step,

    $re,$fn,$vref,
    \@branch,\$out,

  );


  # get match?
  my $iter  = $self->{citer};
  my $match = ($out)

    ? {

      j=>$iter->{j},
      p=>$iter->{prog}->[$iter->{i}]->[1],

    } : undef ;


  # restore and give
  $self->restore_iter();
  $iter->{match}=$match;

  return $out;

};

# ---   *   ---   *   ---
# ^iter F

sub la_step($self,$re,$fn,$vref,$branch,$out) {


  # get ctx
  my $mc   = $self->getmc();
  my $iter = $self->{citer};
  my $prog = $iter->{prog};

  # get ins/operands
  my $point = $iter->{point};
  my $dst   = $iter->{dst};
  my $src   = $iter->{src};

  my $tab={dst=>$dst,src=>$src};
  my $ins=$point->{Q}->[$iter->{j}]->[1];


  # trim past branches
  @$branch=grep {
    $point->{branch}->{idex}
  < $ARG

  } @$branch;


  # terminate lookahead on ret/exit
  my $sysexit=(
     $ins eq 'int'
  && $dst->{-syscall} eq 'exit'

  );

  # we consider these instructions
  # dead ends only when there's no
  # branches left to walk!

  if(

      ($ins eq 'ret' || $sysexit)
  &&! (int @$branch)

  ) {

    return 1;


  # consider branching on c-jmp
  # IF jumping forwards
  } elsif($ins=~ qr{^j[ngl]?[z]?$}) {

    my $from = $point->{branch}->{idex};

    my $to   = $point->{branch}->{vref};
       $to   = $to->{res}->{args}->[0];
       $to   = $to->{id};

    my $ptr  = $mc->search(@$to);
       $to   = $ptr->{p3ptr}->{idex};

    push @$branch,$to if $from < $to;

  };


  # ^compare against vref
  map {

    my $have=$tab->{$ARG};


    # if there is no check, then give true!
    if($fn eq $NOOP) {
      $$out=1;
      return 1;

    # perform check and procceed
    # accto result:
    #
    # * on ret F eq abs 1, then stop
    # * always give true on 1
    #
    # * false on -1 IF there are no
    #   further branches to consider
    #
    # * zero means continue

    } elsif(

      defined $have && (my $ok=$fn->(
      $self,$have,$vref,$ARG

    ))) {

      if($ok == 1) {
        $$out=1;
        return 1;

      } elsif($ok == -1 &&! @$branch) {
        return 1;

      };

    };


  } qw(dst src) if $ins=~ $re;


  return 0;

};

# ---   *   ---   *   ---
# handle intermediate value fetches

sub ldvar($self,$vref,$which) {


  # get ctx
  my $iter  = $self->{citer};

  my $point = $iter->{point};
  my $Q     = $point->{Q};
  my $j     = $iter->{j};


  # skip overwrite check?
  return if ! $vref;

  my $over = int (
     $which eq 'dst'
  && $point->{overwrite}->[$j]

  );


  # skip value re-load?
  if($vref->{loaded}) {

    $self->{moded} |= $over << $vref->{loc}
    if $vref->{loaded} ne 'const';

    return;

  };


  # generate instructions and add
  # them to the assembly queue
  #
  # if no instructions are generated,
  # then this does nothing

  my @have=$self->load($vref,$which);
  $self->insert_ins(@have);

  $self->{moded} |= $over << $vref->{loc};


  return;

};

# ---   *   ---   *   ---
# replace value in instruction operands

sub replvar($self,$vref) {


  # get ctx
  my $iter  = $self->{citer};

  my $point = $iter->{point};
  my $j     = $iter->{j};
  my $k     = $iter->{k};

  my $Q     = $point->{Q};
  my $qref  = $Q->[$j];


  # var is valid for replacement?
  if(

     defined $vref
  && defined $vref->{loc}

  ) {

    my $operand=\$qref->[2+$k];


    # calculating address?
    if(! index $$operand->{type},'m') {

      $self->replmem($operand,$vref);
      $qref->[0]=$$operand->{opsz};


    # ^replace immediate for register!
    } else {

      $$operand={
        type => 'r',
        reg  => $vref->{loc}

      };


      # overwrite operation size?
      if($vref->{ptr}) {


        # compare sizes
        my $old   = $qref->[0];
           $old //= typefet 'word';

        my $new   = $vref->{ptr}->get_type();


        my $sign=(
          $old->{sizeof}
        < $new->{sizeof}

        );


        # TODO: revise this bit
        #
        # do IF dst is smaller
        #    OR src is bigger

        $qref->[0]=$new

        if (! $k) #  &&! $sign
        || (  $k &&  $sign);

      };

    };

  };


  # go next and give
  $iter->{k}++;
  return;

};

# ---   *   ---   *   ---
# TODO:
#
# work out how to best insert
# value into a memory operand
#
# this is involved for a few reasons:
#
# * there are four types of addressing,
#   and we have to consider them all
#
# * the address may require multiple
#   instructions to compute
#
# * conversely, we may be able to work
#   the calculation down to fewer steps


sub replmem($self,$dst,$vref) {


  # get ctx
  my $mc   = $self->getmc();
  my $iter = $self->{citer};
  my $var  = $iter->{var};
  my $args = $$dst->{imm_args};


  # fetch all local and external
  # symbols used in addr
  my @lol=();
  my @ext=();

  map {


    # get by idex
    my $x=$args->[$ARG];

    # is this symbol local to block?
    my $have=$mc->psearch(@{$x->{id}});
    my ($id,@path)=$$have->fullpath;

    @path=$mc->local_deanonid(@path,$id);
    my $full=join '::',@path;


    # ^populate arrays correspondingly
    if(exists $var->{$full}) {
      push @lol,[$ARG,$var->{$full}];

    } else {
      push @ext,[$ARG,$$have];

    };


  # ^filtering non-const elements
  } grep {
    my $x=$args->[$ARG];
    exists $x->{id};

  } 0..@$args-1;


  # pending
  if(@ext) {
    nyi "external symbols in address"

  };

  my $type=(1 < @lol)
    ? 'mlea'
    : 'msum'
    ;

  my $k=0;

  map {

    my ($idex,$src)=@$ARG;
    $args->[$idex]=undef;

    if($type eq 'mlea') {

      if(! $k++) {
        $$dst->{rX}=$src->{loc}+1;

      } else {
        $$dst->{rY}=$src->{loc}+1;

      };


    } else {
      $$dst->{reg}=$src->{loc};

    };


  } @lol;


  # cleanup and give
  $$dst->{type}=$type;
  @$args=grep {defined $ARG} @$args;

  return;

};

# ---   *   ---   *   ---
# check that a value is required
# by this instruction
#
# ie, it must be *loaded* for the
# instruction to work as intended

sub reqvar($self,$vref,$which) {

  my $iter  = $self->{citer};

  my $point = $iter->{point};
  my $j     = $iter->{j};

  return $point->{"load_$which"}->[$j];

};

# ---   *   ---   *   ---
# lookahead F:
# check instruction requires vref

sub la_reqvar($self,$vref,$have,$which) {


  # is value required by this instruction?
  my $same = $have eq $vref;
  my $need = int (
     $same
  && $self->reqvar($vref,$which)

  );


  # corner: value is explicitly discarded,
  # hence not required
  if($same &&! $need && $which eq 'dst') {

    my $iter  = $self->{citer};

    my $point = $iter->{point};
    my $j     = $iter->{j};

    $need=-1
    if $point->{overwrite}->[$j];

  };


  return $need;

};

# ---   *   ---   *   ---
# backup values uppon call

sub on_call($self,$dst,@slurp) {


  # output is an instruction list!
  my @out=();


  # get invoked F
  my $other=$dst->{ptr}->{p3ptr};
     $other=$other->{vref}->{data};

  # get which registers are effectively
  # modified by this F
  my $mask=(
    $other->{vused}
  & $other->{moded}

  );

  # ^match against registers in use at
  # ^this point by the callee
  my $spill=$self->{used} & $mask;


  # ^walk these registers and decide
  # ^which ones need to be preserved

  while($spill) {


    # take next register
    my $idex   =  (bitscanf $spill)-1;
       $spill &= ~(1 << $idex);

    # get currently loaded value
    my $vref=$self->{loadmap}->{$idex};

    # check whether this value is required!
    push @out,$self->spill($vref)

    if ! $vref->{bound}
    &&   $self->lookahead(
      qr{.+}=>\&la_reqvar,
      $vref

    );

  };


  # clear bindings
  map    {$ARG->{bound}=undef}
  values %{$self->{citer}->{var}};

  # combine register use and give
  $self->{moded} |= $mask;
  return @out;

};

# ---   *   ---   *   ---
# ~

sub get_next_call($self) {


  # get ctx
  my $mc     = $self->getmc();
  my $main   = $mc->get_main();

  my $iter   = $self->{citer};
  my $point  = $iter->{point};


  # get F we're binding to
  $self->lookahead(
    qr{call}=>$NOOP=>undef

  # ^or throw ;>
  ) or $main->bperr(

    $point->{branch},

    'used [err]:%s without matching [ctl]:%s',
    args=>[(St::cf 1,1),'call'],

  );


  # get F meta
  my $match = $iter->{match};
  my $mp    = $match->{p};
  my $mj    = $match->{j};

  my $id    = $mp->{Q}->[$mj]->[2]->{id};
  my $ptr   = $mc->search(@$id);

  my $blk   = $ptr->{p3ptr}->{vref};
     $blk   = $blk->{data};


  return $blk;

};

# ---   *   ---   *   ---
# mark value as storing the
# output of call

sub on_bind($self,@slurp) {


  # get ctx
  my $mc    = $self->getmc();
  my $main  = $mc->get_main();

  my $iter  = $self->{citer};
  my $point = $iter->{point};

  my $blk   = $self->get_next_call();


  # get the vars on the caller's side
  my $asm   = $point->{Q}->[$iter->{j}];
  my (@dst) = @{$asm}[2..@$asm-1];

  @dst=map {$self->vname($ARG)} @dst;

  # ^compare to declared outputs on the
  # ^side of the callee
  my $blkio = $blk->{io}->{out};
  my @src   = @{$blkio->{var}->{-order}};


  # check array size match
  $main->bperr(

    $point->{branch},

    "[ctl]:%s '%s' only has "
  . "[num]:%u output(s);\n"

  . "cannot [err]:%s [num]:%u value(s) to it",

    args=>[
      proc=>$blk->{name},(int @src),
      bind=>(int @dst),

    ],

  ) if @dst > @src;


  # mark destination as bound
  #
  # this makes it so it won't be spilled
  # when being overwritten by a call

  map {

    my ($x,$y)=(
      $iter->{var}->{$dst[$ARG]},
      $blkio->{var}->{$src[$ARG]},

    );


    # need intermediate load?
    if((! defined $x->{loc})) {


      # are we overwriting another value?
      my $old=$self->{loadmap}->{$y->{loc}};
      if(defined $old) {

        $self->insert_ins(
          $self->chkuse($y)

        );

        $old->{loc}=undef;

      };


      $x->{loc}    = $y->{loc};
      $x->{loaded} = 1;

      $self->{loadmap}->{$x->{loc}}=$x;

      $self->{used} |= 1 << $x->{loc};


    # using different registers?
    } elsif($x->{loc} ne $y->{loc}) {
      nyi "mov bound output";

    };


    $x->{bound}=$y;

  } 0..$#dst;


  # cleanup and give
  $self->remove_ins();
  return 0;

};

# ---   *   ---   *   ---
# ^~

sub on_pass($self,@slurp) {


  # get ctx
  my $mc    = $self->getmc();
  my $main  = $mc->get_main();

  my $iter  = $self->{citer};
  my $point = $iter->{point};

  my $blk   = $self->get_next_call();


  # get the vars on the caller's side
  my $asm   = $point->{Q}->[$iter->{j}];
  my (@dst) = @{$asm}[2..@$asm-1];

  @dst=map {$self->vname($ARG)} @dst;

  # ^compare to declared inputs on the
  # ^side of the callee
  my $blkio = $blk->{io}->{in};
  my @src   = @{$blkio->{var}->{-order}};


  # put each value in the corresponding
  # register

  map {

    my ($x,$y)=(
      $iter->{var}->{$dst[$ARG]},
      $blkio->{var}->{$src[$ARG]},

    );


    # validate
    $main->bperr(

      $point->{branch},

      "unitialized value '%s' "
    . "passed to [goodtag]:%s",

      args=>[$x->{name},$blk->{name}],

    ) if ! $x->{loaded};


    # using different registers?
    if($x->{loc} ne $y->{loc}) {


      # generate dummy value
      my $ptr  = $y->{ptr};
      my $type = ($ptr->{ptr_t})
        ? $ptr->{ptr_t}
        : $ptr->{type}
        ;

      my $rY  = {type=>'r',reg=>$y->{loc}};
      my $reg = $self->chkvar(
        $self->vname($rY),-1

      );


      # perform intermediate load,
      # preserving the location of any
      # overwritten values
      my $old=$self->{loadmap}->{$y->{loc}};

      $self->ldvar($reg,'dst');
      $self->insert_ins([

        $type,
        'ld',

        $rY,
        {type=>'r',reg=>$x->{loc}},

      ]);


      # restore location if necessary
      #
      # re-loading of this value will be
      # performed later by any instructions
      # that require it!

      if(defined $old) {
        $old->{loc}=$y->{loc};

      };

    };

  } 0..$#dst;


  $self->remove_ins();
  return 0;

};

# ---   *   ---   *   ---
1; # ret
