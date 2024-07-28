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

  our $VERSION = v0.01.1;#a
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

    Q     => {

      early  => [],
      late   => [],

      ribbon => [],

    },

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
    proc => [qw(const readable executable)],

  },

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
# add attr to obj

sub addattr($self,$name,$value) {
  $self->{$name}=$value;
  return;

};

# ---   *   ---   *   ---
# add method to execution queue

sub enqueue($self,$name,@args) {
  push @{$self->{Q}->{$name}},\@args;
  return;

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

  };


  # set and give
  push @{$dst->{-order}},$name;
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


  return @out;

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
# place backup in register
# use defv if no backup!

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

    my $bit=1 << $dst->{loc};


    # check that register is in use
    my $key=$dst->{loc};
    my $old=$self->{loadmap}->{$key};


    # we need first check whether
    # this value is required by a
    # future instruction

    if(defined $old) {


      # * case 0: required, so backup the
      #   value and let this very F restore
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


  # need to allocate register?
  if(! defined $dst->{loc}) {


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
    $self->{vused}   |= $bit;
    $dst->{loc}       = $idex;

    $anima->{almask}  = $old;

  };


  # avoid unnecessary loads
  my $iter  = $self->{citer};
  my $point = $iter->{point};
  my $j     = $iter->{j};

  goto skip if (
  !  $point->{"load_$which"}->[$j]
  || $dst->{loaded}

  );


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

    my $main=$mc->get_main();

    $main->bperr(

      $self->{iter}->{point}->{branch},

      "attempt to load undefined value '%s'",
      args=>[$dst->{name}],

    );


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

  $dst->{loaded}=1;

  my $key=$dst->{loc};
  $self->{loadmap}->{$key}=$dst;

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


  # have register?
  my $out=null;
  if($var->{type} eq 'r') {
    $out="\$$var->{reg}";

  # have alias?
  } else {

    $out   = $var->{imm_args}->[0];
    $out   = $out->{id}->[0];

    $out //= $var->{id}->[0];

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

    var   => {},
    prog  => undef,

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
    qw  (i j k point)

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
  qw  (i j k point);


  return;

};

# ---   *   ---   *   ---
# initial run-through of block
#
# this builds context from which
# it can be later analyzed

sub build_iter($self,$recalc=0) {


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
  return [

    $iter->{point},

    ($argcnt)
      ? ($dst,$src)
      : ($dst)
      ,

  ];

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
  return [$self->{citer}->{point}];

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
  $iter->{i}++;
  $dst->{-syscall}=$code;

  $iter->{point}->{Q}->[$iter->{j}]->[0]=
    typefet 'dword';

  return [$iter->{point},$dst];

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
  $self->set_scope();

  map {

    my $dst=$iter->{var}->{$ARG};

    $dst->{ptr}=$mc->search($ARG)
    if $dst->{loaded} ne 'const';

    if(

       defined $dst->{ptr}
    && exists  $dst->{ptr}->{p3ptr}

    ) {

      $dst->{loaded} = 'const';
      $dst->{loc}    = undef;

    };


  } $self->varkeys(io=>'all');


  return;

};

# ---   *   ---   *   ---
# process all timeline points

sub procblk($self) {


  # get ctx
  my $iter=$self->{citer};
  my $prog=$iter->{prog};


  # walk timeline
  $iter->{i}     = 0;
  $iter->{point} = undef;

  map {
    $self->procins($ARG);
    $iter->{i}++;

  } @$prog;


  # does this block utilize the stack?
  if($self->{stack}->{-size}) {
    $self->stack_setup();
    $self->stack_cleanup();

  };

  return;

};

# ---   *   ---   *   ---
# ^process instruction in timeline point

sub procins($self,$data) {


  # get ctx
  my $iter=$self->{citer};

  # get instruction and operands
  my ($point,$dst,$src)=
    $self->timeline_step($data);

  my $j   = $iter->{j};
  my $ins = $point->{Q}->[$j]->[1];

  # generate intermediate loads
  $self->ldvar($dst,'dst');
  $self->ldvar($src,'src');


  # handle edge cases
  my $gentab={
    call => \&on_call,

  };

  my $genfn=$gentab->{$ins};

  if(defined $genfn) {
    my @ins=$genfn->($self,$dst,$src);
    $self->insert_ins(@ins);

  };


  # perform operand replacements
  $iter->{k}=0;

  $self->replvar($dst);
  $self->replvar($src);


  # go next and give
  $iter->{j}++;
  return;

};

# ---   *   ---   *   ---
# get next instruction

sub timeline_step($self,$data) {


  # get ctx
  my $iter  = $self->{citer};
  my $point = $iter->{point};


  # unpack
  my ($newp,$dst,$src)=@$data;

  # stepping on new timeline point?
  if(! $point || $point ne $newp) {
    $iter->{point} = $newp;
    $iter->{j}     = 0;

  };


  return ($newp,$dst,$src);

};

# ---   *   ---   *   ---
# put instruction array at pointer

sub insert_ins($self,@ins) {


  # get ctx
  my $iter  = $self->{citer};

  my $point = $iter->{point};
  my $Q     = $point->{Q};
  my $j     = $iter->{j};


  # modify assembly queue
  @$Q=(
    @{$Q}[0..$j-1],
    @ins,
    @{$Q}[$j..@$Q-1],

  );

  # ^move to end of generated
  $iter->{j} += int @ins;


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


  # add equivalent of 'enter' instruction ;>
  my $beg=$prog->[0]->[0];

  unshift @{$beg->{Q}},

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

  ];


  return;

};

# ---   *   ---   *   ---
# ^add cleanup for each ret

sub stack_cleanup($self) {


  # get ctx
  my $iter  = $self->{citer};
  my $prog  = $iter->{prog};

  my $mc    = $self->getmc();
  my $anima = $mc->{anima};
  my $ISA   = $mc->{ISA};

  my $qword = typefet 'qword';
  my $size  = $self->{stack}->{-size};


  # walk timeline
  $iter->{i}     = 0;
  $iter->{point} = undef;


  # look for every ret
  map {


    # get next point
    my ($point)=$self->timeline_step($ARG);
    $iter->{i}++;


    # have a ret?
    my $j    = $iter->{j};
    my $Q    = $point->{Q};

    my $have = $Q->[$j];


    # ^add a leave instruction if so
    $self->insert_ins([$qword,'leave'])
    if $have->[1] eq 'ret';

    $iter->{j}++;


  } @$prog;


  # clear and give
  $mc->{stack}->reset();
  return;

};

# ---   *   ---   *   ---
# walk iter from current position
# and find mention of vref

sub lookahead($self,$re,$fn,$vref) {


  # get ctx
  my $mc   = $self->getmc();
  my $iter = $self->{citer};
  my $prog = $iter->{prog};


  # walk program from current onwards
  my @branch=();
  $self->backup_iter();

  map {


    # get ins/operands
    my ($newp,$dst,$src)=
      $self->timeline_step($ARG);

    my $tab={dst=>$dst,src=>$src};
    my $ins=$newp->{Q}->[$iter->{j}]->[1];


    # trim past branches
    @branch=grep {
      $newp->{branch}->{idex}
    < $ARG

    } @branch;


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
    &&! (int @branch)

    ) {

      $self->restore_iter();
      return 0;


    # consider branching on c-jmp
    # IF jumping forwards
    } elsif($ins=~ qr{^j[ngl]?[z]?$}) {

      my $from = $newp->{branch}->{idex};

      my $to   = $newp->{branch}->{vref};
         $to   = $to->{res}->{args}->[0];
         $to   = $to->{id};

      my $ptr  = $mc->search(@$to);
         $to   = $ptr->{p3ptr}->{idex};

      push @branch,$to if $from < $to;

    };


    # ^compare against vref
    map {

      my $have=$tab->{$ARG};


      # perform check and procceed
      # accto result:
      #
      # * on ret F eq abs 1, then stop
      # * give true on 1, false on -1
      #
      # * zero means continue

      if(

        defined $have && (my $ok=$fn->(
        $self,$have,$vref,$ARG

      ))) {

        if($ok == 1) {
          $self->restore_iter();
          return 1;

        } elsif($ok == -1) {
          $self->restore_iter();
          return 0;

        };

      };


    } qw(dst src) if $ins=~ $re;

    $iter->{j}++;
    $iter->{i}++;


  } @{$prog}[$iter->{i}..@$prog-1];


  # value is not required, give false
  $self->restore_iter();
  return 0;

};

# ---   *   ---   *   ---
# handle intermediate vale fetches

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


    $qref->[2+$k]={
      type => 'r',
      reg  => $vref->{loc}

    };


    # overwrite operation size?
    if($vref->{ptr}) {


      # compare sizes
      my $old  = $qref->[0];
      my $new  = $vref->{ptr}->{type};


      my $sign = (
        $old->{sizeof}
      < $new->{sizeof}

      );


      # do IF dst is smaller
      #    OR src is bigger

      $qref->[0]=$new

      if (! $k &&! $sign)
      || (  $k &&  $sign);

    };

  };


  # go next and give
  $iter->{k}++;
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

    if $self->lookahead(
      qr{.+}=>\&la_reqvar,
      $vref

    );

  };


  return @out;

};

# ---   *   ---   *   ---
1; # ret
