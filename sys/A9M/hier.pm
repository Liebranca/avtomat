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

  use Arstd::IO;

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
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

    stk   => {-size=>0x00},

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

    if(defined $old) {


      # we need first check whether
      # this value is required by a
      # future instruction
      #
      #
      # * case 0: not required, so simply
      #   overwrite the value without
      #   backing it up -- ie, do nothing ;>
      #
      # * case 1: required, so backup the
      #   value and let this very F restore
      #   it when that point is reached

      if($self->lookahead(
        qr{.+}=>\&la_reqvar,
        $old

      )) {


        # get addr in stack
        my $base = $stack->{base}->load();
        my $off  = $base-$old->{ptr}->{addr};

        # generate store
        push @out,[

          $old->{ptr}->{type},
          'st',

          {type=>'mstk',imm=>$off},
          {type=>'r',reg=>$old->{loc}},

        ];


      };


      # unload previous value
      delete $self->{loadmap}->{$key};

      # adjust masks
      my $io   = $self->{io};
      my $nbit = ~$bit;

      # TODO: make this less messy
      $self->{used}      &= $nbit;
      $io->{out}->{used} &= $nbit;
      $io->{in}->{used}  &= $nbit;

      $old->{loc}    = undef;
      $old->{loaded} = 0;

    };


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


  # make room in stack
  $stack->repoint($dst->{ptr})
  if ! $stack->is_ptr($dst->{ptr});


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


    $dst->{ptr}->store($x);
    $dst->{defv}=undef;


  # ^nope, load from stack
  } else {

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
    prev  => undef,

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

    map {$self->get_ins($ARG)}
    @{$iter->{point}->{Q}};


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

  $iter->{i}++;


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

  }->{$ins};

  return (defined $fn)
    ? $fn->($self) : () ;

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

  $self->{vused} |=
    $anima->regmask(qw(cr chan));


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


  # generate intermediate loads
  $self->ldvar($dst,'dst');
  $self->ldvar($src,'src');


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


      # if this value is required by
      # this instruction, then give true
      if(

         defined $have
      && $fn->($self,$have,$vref,$ARG)

      ) {

        $self->restore_iter();
        return 1;

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


  # skip?
  return if ! $vref || $vref->{loaded};


  # get ctx
  my $iter  = $self->{citer};

  my $point = $iter->{point};
  my $Q     = $point->{Q};
  my $j     = $iter->{j};


  # generate instructions and add
  # them to the assembly queue
  #
  # if no instructions are generated,
  # then this does nothing

  my @have=$self->load($vref,$which);

  @$Q=(
    @{$Q}[0..$j-1],
    @have,
    @{$Q}[$j..@$Q-1],

  );


  # ^move to end of generated
  $iter->{j} += int @have;


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

  return (
     $have eq $vref
  && $self->reqvar($vref,$which)

  );

};

# ---   *   ---   *   ---
1; # ret
