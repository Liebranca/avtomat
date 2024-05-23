#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ISA:OPERA
# The things we do to memory...
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::ISA::opera;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_words);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;
  use Bpack;
  use Warnme;

  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::PM;

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.0;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  table => [


    # imm/mem/reg to reg
    ld => {

      load_dst => 0,

      dst      => 'r',
      src      => 'rmi',

      immbig   => 1,

    },

    # reg to mem
    st => {

      fn       => 'ld',
      load_dst => 0,

      dst      => 'm',
      src      => 'r',

    },


    # ^conditional variants
    (map {

      $ARG => {

        load_dst => 1,

        dst      => 'r',
        src      => 'r',

        fix_size => ['qword'],

      },

    } qw(lz lnz lg lgz ll llz)),


    # load chan!
    self => {

      fn        => 'load_chan',
      ipret_fn  => 'set_scope',

      load_dst  => 1,

      dst       => 'i',

      immbig    => 1,
      argcnt    => 1,

      overwrite => 0,

    },


    # our beloved
    # load effective address ;>
    lea => {

      load_dst => 0,
      load_src => 0,

      dst      => 'r',
      src      => 'm',

    },



    # bitops
    xor => {
      dst => 'r',
      src => 'ri',

    },

#
#  and => {
#    dst  => 'r',
#    src  => 'ri',
#
#  },
#
#  or => {
#    dst  => 'r',
#    src  => 'ri',
#
#  },
#
#  not => {
#
#    argcnt => 1,
#
#    dst    => 'r',
#    src    => 'ri',
#
#  },
#
#
#  # bitmask, all ones
#  bones => {
#
#    dst        => 'r',
#    src        => 'ri',
#
#    fix_immsrc => 1,
#    fix_regsrc => 3,
#
#  },
#
#
#  # bitshift left/right
#  shl => {
#
#    dst        => 'r',
#    src        => 'ri',
#
#    fix_immsrc => 1,
#    fix_regsrc => 3,
#
#  },
#
#  shr => {
#
#    dst        => 'r',
#    src        => 'ri',
#
#    fix_immsrc => 1,
#    fix_regsrc => 3,
#
#  },
#
#
#  # bitscan <3
#  bsf => {
#    dst => 'r',
#    src => 'r',
#
#  },
#
#  bsr => {
#    dst => 'r',
#    src => 'r',
#
#  },
#
#
#  # bit rotate right
#  # a thing of pure beauty!
#  ror => {
#
#    dst        => 'r',
#    src        => 'ri',
#
#    fix_immsrc => 1,
#    fix_regsrc => 3,
#
#  },
#
#  # ^rotate left ;>
#  rol => {
#
#    dst        => 'r',
#    src        => 'ri',
#
#    fix_immsrc => 1,
#    fix_regsrc => 3,
#
#  },
#
#
  # math
  add => {
    dst  => 'r',
    src  => 'ri',

  },

  sub => {

    fn   => '_sub',

    dst  => 'r',
    src  => 'ri',

  },


  mul => {
    dst  => 'r',
    src  => 'r',

  },

#  # the mnemonic for 'division' should be 'avoid'
#  # but that may confuse some people ;>
#  div => {
#    dst  => 'r',
#    src  => 'r',
#
#  },


  # ++/--
  inc => {
    argcnt => 1,
    dst    => 'r',

  },

  dec => {
    argcnt => 1,
    dst    => 'r',

  },


#  # negate
#  neg => {
#
#    argcnt => 1,
#
#    dst    => 'r',
#    src    => 'ri',
#
#  },
#

    # stack ctl
    push => {

      fn        => '_push',

      dst       => 'rmi',
      argcnt    => 1,
      overwrite => 0,

      fix_size  => ['qword'],

    },

    pop => {

      fn        => '_pop',

      dst       => 'r',
      argcnt    => 1,
      overwrite => 1,

      load_dst  => 0,
      fix_size  => ['qword'],

    },


    # go somewhere else ;>
    jmp => {

      argcnt    => 1,
      dst       => 'rmi',

      overwrite => 0,
      fix_size  => ['qword'],

    },

    # ^conditionally!
    (map {

      $ARG => {

        argcnt    => 1,
        dst       => 'rmi',

        overwrite => 0,
        fix_size  => ['qword'],

      },

    } qw(jz jnz jg jgz jl jlz)),


    # a special jump ;>
    call => {

      argcnt    => 1,
      dst       => 'rmi',

      overwrite => 0,
      fix_size  => ['qword'],

    },


    # ^accessories sold separately
    enter => {argcnt=>0},
    leave => {argcnt=>0},
    ret   => {argcnt=>0},


    # syscall in disguise!
    exit => {

      fn         => '_exit',

      argcnt     => 1,
      dst        => 'i',

      overwrite  => 0,
      fix_size   => ['byte'],
      fix_immsrc => 1,

    },


    # comparison!
    cmp => {

      fn  => '_cmp',

      dst => 'r',
      src => 'ri',

      overwrite => 0,

    },

    test => {

      dst => 'r',
      src => 'ri',

      overwrite => 0,

    },


    # check equality
    cmpe => {

      fn  => '_eq',

      dst => 'r',
      src => 'ri',

      overwrite => 0,

    },


    # meta instructions
    sex => {

      dst    => 'r',
      argcnt => 1,

      fix_size  => ['qword'],

    },


  ],


  op_to_ins => {qw(

    =   ld
    ^   xor

    +   add
    -   sub
    *   mul

    ==  cmpe

  )},


  list    => sub {[array_keys $_[0]->table()]},
  cX_list => [qw(z nz g gz l lz)],

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {
  return bless \%O,$class;

};

# ---   *   ---   *   ---
# run generic op on value

sub opera($self,$fn,$value) {

  my @out = ();
  my @Q   = $value;

  while(@Q) {

    my $x=shift @Q;

    (is_arrayref $x)
      ? unshift @Q,@$x
      : push    @out,$fn->($self,$x)
      ;

  };


  return @out;

};

# ---   *   ---   *   ---
# make prim from vector elems

sub flatten($self,$ezy,$bits=undef) {

  # get bounds
  $bits //= $ezy;
  $bits   = 0x40 if $bits > 0x40;
  $ezy    = 0x40 if $ezy  > 0x40;


  # fstate
  my $out=0x00;
  my $cnt=0x00;

  # fdef
  sub ($x) {

    # wrap around?
    if($cnt == $bits) {
      $out=0x00;
      $cnt=0x00;

    };


    # cat next element
    $out |= $x << $cnt;
    $cnt += $ezy;

    # give on cap hit
    ($cnt == $bits) ? $out : () ;

  };

};

# ---   *   ---   *   ---
# procs operation source

sub asval($src) {

  (is_arrayref $src)
    ? (array_flatten $src)
    : ($src)
    ;

};

# ---   *   ---   *   ---
# src to dst

sub ld($self,$type,$src) {
  my @src=asval $src;
  sub {shift @src};

};

# ---   *   ---   *   ---
# helpers for conditionals

sub ivflag($flagref) {
  map {int($ARG=~ s[^n][])} @$flagref;

};

sub flagchk($mode,$anima,$flagref,$ivref) {


  # get array of values
  my (@chk)=$anima->get_flags(@$flagref);

  # ^apply inversion!
  map {
    $chk[$ARG] =! $chk[$ARG]
    if $ivref->[$ARG]

  } 0..$#chk;


  # combine results and give
  my $out=$chk[0];

  map {

    $out={
      and => $out & $ARG,
      or  => $out | $ARG,
      xor => $out ^ $ARG,

    }->{$mode};

  } @chk[1..$#chk];


  return $out;

};

# ---   *   ---   *   ---
# ^the conditions themselves ;>

sub cX_z  {q[or  => qw(zero)]};
sub cX_nz {q[or  => qw(nzero)]};

sub cX_g  {q[and => qw(nsign nzero)]};
sub cX_gz {q[or  => qw(nsign zero)]};

sub cX_l  {q[or  => qw(sign)]};
sub cX_lz {q[or  => qw(sign zero)]};

# ---   *   ---   *   ---
# conditional load

sub cld($self,$type,$src,$mode,@flag) {


  # negate flag?
  my @iv  = ivflag \@flag;
  my @src = asval $src;


  # make F
  sub ($ice,$x) {

    # get ctx
    my $mc    = $ice->getmc();
    my $anima = $mc->{anima};

    # eval and give
    my $y   = shift @src;
    my $chk = flagchk $mode,$anima,\@flag,\@iv;

    return ($chk) ? $y : $x ;

  };

};

# ---   *   ---   *   ---
# loads segment idex to chan

sub load_chan($self,$type) {


  sub ($ice,$x) {

    # get ctx
    my $mc    = $ice->getmc();
    my $anima = $mc->{anima};
    my $chan  = $anima->{chan};

    # ^set segment
    $chan->store($x);

    return;

  };

};

# ---   *   ---   *   ---
# ^ipret v; sets search path

sub set_scope($self,$main,$data) {


  # get ctx
  my $mc    = $self->getmc();
  my $frame = $mc->{cas}->{frame};
  my $eng   = $main->{engine};


  # make F
  my $out=sub {


    # need to make copy?
    my $src={%$data} if is_hashref $data;


    # deref
    $eng->opera_static([$src],1);

    # ^fetch segment and make current
    my ($seg)=$mc->flatptr($src->{imm});
    $mc->scope($seg->{value});

  };

  $out->();
  return $out;

};

# ---   *   ---   *   ---
# exclusive OR

sub xor($self,$type,$src) {
  my @src=asval $src;
  sub ($ice,$x) {$x ^ shift @src};

};

# ---   *   ---   *   ---
# arithmetic solver
#
# we use this to perform the
# actual operation and set the
# flags registers, as the conditions
# are more or less the same

sub ari($self,$type,$anima,$x,$y) {


  # get caller
  my $key=St::cf 2,1;

  if($key=~ qr{(?:inc|dec)}) {

    $key={
      inc=>'add',
      dec=>'_sub',

    }->{$key};

  };


  # get op result
  my $z={
    add  => $x+$y,
    _sub => $x-$y,

  }->{$key} & $type->{sizebm};


  # get sign of operands and result
  my @sign=(
    $x & $type->{signbit},
    $y & $type->{signbit},
    $z & $type->{signbit},

  );


  # get overflow
  my $over={

    add  => (
       ($sign[0] == $sign[1])
    && ($sign[0] != $sign[2])

    ),

    _sub => (

       ($sign[0] != $sign[1])
    && ($sign[0] != $sign[2])

    ),

  }->{$key};


  # update flags register
  $anima->set_flags(

    zero  => ! $z,

    sign  => $sign[2],
    carry => $z < $y,

    over  => $over,

  );


  return $z;

};

# ---   *   ---   *   ---
# ^and this we use to generate the
# wrapper methods!

sub defop($self,$type,$src) {


  # get name of F
  my $key=St::cf 2;
  my @src=asval $src;


  # give wrapper
  return sub ($ice,$x) {

    # deanon
    local *__ANON__ = $key;

    # get ctx
    my $mc    = $ice->getmc();
    my $anima = $mc->{anima};

    # eval and give
    my $y=shift @src;
    my $z=$self->ari($type,$anima,$x,$y);

    return $z;

  };

};

# ---   *   ---   *   ---
# arithmetic icef*ck!

subwraps '$self->defop' => q(
  $self,$type,$src

) => (

  map {[$ARG => '$type,$src']}
  qw  (add _sub)

);

subwraps '$self->defop' => q(
  $self,$type

) => (

  map {[$ARG => '$type,1']}
  qw(inc dec)

);

# ---   *   ---   *   ---
# multiplication

sub mul($self,$type,$src) {
  my @src=asval $src;
  sub ($x) {$x * shift @src};

};

# ---   *   ---   *   ---
# set insptr

sub jmp($self,$type) {

  sub ($ice,$x) {

    # get ctx
    my $mc    = $ice->getmc();
    my $anima = $mc->{anima};
    my $rip   = $anima->{rip};

    # write to rip
    my $pos=$mc->flatjmp($x);
    $rip->store($pos,deref=>0);
    return;

  };

};

# ---   *   ---   *   ---
# ^conditional

sub cjmp($self,$type,$mode,@flag) {


  # negate flag?
  my @iv=ivflag \@flag;

  # make F
  sub ($ice,$x) {

    # get ctx
    my $mc    = $ice->getmc();
    my $anima = $mc->{anima};
    my $rip   = $anima->{rip};


    # ^eval and write to rip
    my $chk=flagchk $mode,$anima,\@flag,\@iv;

    $rip->store($mc->flatjmp($x),deref=>0)
    if $chk;


    return;

  };

};

# ---   *   ---   *   ---
# icef*ck of conditional jumps and loads!

sub cX_make($name,$char,$sig) {

  my $class=St::cpkg;

  return subwraps

  "\$self->$name",
  "\$self,$sig",

  map {

    my $fn = "cX_$ARG";
       $fn = \&$fn;

    ["$char$ARG" => "$sig," . $fn->()];


  } @{$class->cX_list}

};

cX_make cld  => l => q($type,$src);
cX_make cjmp => j => q($type);

# ---   *   ---   *   ---
# jump to F

sub call($self,$type) {


  # make F
  my $jmp  = $self->jmp($type);
  my $push = $self->_push(typefet 'qword');

  sub ($ice,$x) {


    # get ctx
    my $mc    = $ice->getmc();
    my $anima = $mc->{anima};
    my $rip   = $anima->{rip};


    # backup current
    my $pos=$rip->load(deref=>0);
    $push->($ice,$pos);

    # get destination
    $x=$mc->flatjmp($x);

    # ^take the jump!
    $jmp->($ice,$x);


    return;

  };

};

# ---   *   ---   *   ---
# ^get ready!

sub enter($self,$type) {


  # TODO: get frame size!
  my $fsz=0x08;

  # make F
  my $push = $self->_push(typefet 'qword');

  sub ($ice) {

    return if ! $fsz;


    # get ctx
    my $mc    = $ice->getmc();
    my $stack = $mc->{stack};
    my $sp    = $stack->{ptr};
    my $sb    = $stack->{base};


    # setup stack frame
    $push->($ice,$sb->load());

    my $x=$sp->load();
    $sb->store($x);

    $x -= 0x8;
    $sp->store($x);

    return;

  };

};

# ---   *   ---   *   ---
# ^get out!

sub leave($self,$type) {


  # TODO: get frame size!
  my $fsz=0x08;

  # make F
  my $pop = $self->_pop(typefet 'qword');

  sub ($ice) {

    return if ! $fsz;


    # get ctx
    my $mc    = $ice->getmc();
    my $stack = $mc->{stack};
    my $sp    = $stack->{ptr};
    my $sb    = $stack->{base};


    # clear stack frame
    my $x=$sb->load();

    $sp->store($x);
    $sb->store($pop->($ice));

    return;

  };

};

# ---   *   ---   *   ---
# ^come back!

sub ret($self,$type) {


  # make F
  my $jmp = $self->jmp($type);
  my $pop = $self->_pop(typefet 'qword');

  sub ($ice,$x) {

    # reset previous position ;>
    my $pos=$pop->($ice);
    $jmp->($ice,$pos);

    return;

  };

};

# ---   *   ---   *   ---
# a syscall in disguise ;>

sub _exit($self,$type) {

  sub ($ice,$x) {
    return ('$:LAST;>',$x);

  };

};
# ---   *   ---   *   ---
# compare two values by substraction

sub _cmp($self,$type,$src) {


  # make F
  my @src=asval $src;
  sub ($ice,$x) {

    # get ctx
    my $mc    = $ice->getmc();
    my $anima = $mc->{anima};

    # substract src from dst
    my $y = shift @src;
    my $z = $x-$y;


    # ^derive flags from result
    $anima->set_flags(
      zero  => ! $z,
      sign  => $z & $type->{signbit},

    );

    return $anima->{flags};

  };

};

# ---   *   ---   *   ---
# ^compare by AND

sub test($self,$type,$src) {


  # make F
  my @src=asval $src;
  sub ($ice,$x) {

    # get ctx
    my $mc    = $ice->getmc();
    my $anima = $mc->{anima};

    # substract src from dst
    my $y = shift @src;
    my $z = $x & $y;


    # ^derive flags from result
    $anima->set_flags(
      zero  => ! $z,
      sign  => $z & $type->{signbit},

    );

    return $anima->{flags};

  };

};

# ---   *   ---   *   ---
# ^get equality

sub _eq($self,$type,$src) {


  # assume values are equal
  my @src=asval $src;
  my $out=1;


  # ^then challenge that assumption ;>
  my $cmp=$self->_cmp($type,$src);
  sub ($ice,$x) {

    # get ctx
    my $mc    = $ice->getmc();
    my $anima = $mc->{anima};

    # run comparison
    my $y=shift @src;
    $cmp->($x);


    # unset if unequal and give
    $out &=~ ($anima->get_flags('zero'))[0];

    return (! @src) ? $out : () ;

  };

};

# ---   *   ---   *   ---
# put on stack

sub _push($self,$type) {


  sub ($ice,$x) {


    # get ctx
    my $mc    = $ice->getmc();
    my $stack = $mc->{stack};
    my $ptr   = $stack->{ptr};
    my $mem   = $stack->{mem};


    # move ptr
    my $have  = $ptr->load();
       $have -= $type->{sizeof};

    # ^write at new position
    $ptr->store($have);
    $mem->store($type,$x,$have);

    return;

  };

};

# ---   *   ---   *   ---
# take from stack

sub _pop($self,$type) {

  sub ($ice) {

    # get ctx
    my $mc    = $ice->getmc();
    my $stack = $mc->{stack};
    my $ptr   = $stack->{ptr};
    my $mem   = $stack->{mem};

    # get value at current position
    my $have = $ptr->load();
    my $x    = $mem->load($type,$have);

    # ^move to previous
    $have += $type->{sizeof};
    $ptr->store($have);

    return $x;

  };

};

# ---   *   ---   *   ---
# bifshift right

sub shr($type,$bits) {

  # inner state
  my $left = 0;
  my $prev = undef;
  my $mask = bitmask($bits);
  my $pos  = $type->{sizebs} - $bits;

  # ^inner F
  sub ($x) {

    $left   = $x  & $mask;

    $x      = $x    >> $bits;
    $$prev |= $left << $pos if $prev;


   $prev   = \$x;
    $prev;

  };

};

# ---   *   ---   *   ---
# bitshift left

sub shl($type,$bits) {

  # inner state
  my $left   = 0;
  my $right  = 0;

  my $mask   = bitmask($bits);
  my $pos    = $type->{sizebs} - $bits;
     $mask <<= $pos;

  # ^inner F
  sub ($x) {

    $left  = ($x  & $mask);
    $x     = ($x << $bits) | $right;

    $right = ($left >> $pos);
    $x;

  };

};

# ---   *   ---   *   ---
# bitrotate right

sub ror($type,$bits) {


  # inner state
  my $left = undef;
  my $cnt  = 0;

  my $mask = bitmask($bits);
  my $pos  = $type->{sizebs} - $bits;

  # inner sub-F
  my $shr=shr($type,$bits);


  # inner F
  sub ($x) {

    $left=($x & $mask) << $pos
    if ! defined $left;

    $x    = $shr->($x);

    $cnt += $type->{sizebs};
    $$x  |= $left if $cnt >> 3 == $type->{sizeof};

    $x;

  };

};

# ---   *   ---   *   ---
# bitrotate left

sub rol($type,$bits) {

  # inner state
  my $left   = undef;
  my $first  = undef;
  my $cnt    = 0;

  my $mask   = bitmask($bits);
  my $pos    = $type->{sizebs} - $bits;
     $mask <<= $pos;

  # inner sub-F
  my $shl=shl($type,$bits);

  # inner F
  sub ($x) {

    $first   = \$x if ! defined $first;
    $left    = ($x & $mask) >> $pos;

    $x       = $shl->($x);

    $cnt    += $type->{sizebs};
    $$first |= $left if $cnt >> 3 == $type->{sizeof};

    \$x;

  };

};

# ---   *   ---   *   ---
# makes tree from s-expression

sub sex($self,$type) {

  sub ($ice,$x) {


    # get ctx
    my $mc   = $ice->getmc();
    my $main = $mc->get_main();

    # fetch string
    my ($seg,$off)=$mc->flatptr($x);
    my $s=$seg->load(cstr=>$off);

    # [conversion to tree goes here]
    my $frame = $main->{tree}->{frame};
    my $tree  = $frame->from_sexp($s);

    $tree->prich();
    exit;

    return $x;

  };


};

# ---   *   ---   *   ---
# translates from operation
# symbol to instruction

sub xlate($self,$sym,@args) {

  my $tab  = $self->op_to_ins;
  my $name = $tab->{$sym}

  or return warn_invalid($sym);


  # edge case: load or store?
  if($name eq 'copy') {

    $name=($args[0]->{type}=~ qr{^m})
      ? 'store'
      : 'load'
      ;

  };


  return $name;

};

# ---   *   ---   *   ---
# ^errme

sub warn_invalid($sym) {

  Warnme::invalid 'opera-xlate',

  obj  => $sym,
  give => null;

};

# ---   *   ---   *   ---
1; # ret
