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

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
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

      dst       => 'rmi',

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
#
#
#  # ++/--
#  inc => {
#    argcnt => 1,
#    dst    => 'r',
#
#  },
#
#  dec => {
#    argcnt => 1,
#    dst    => 'r',
#
#  },
#
#
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

    cmp => {

      fn  => '_cmp',

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


  ],


  op_to_ins => {qw(

    =   ld
    ^   xor

    +   add
    -   sub
    *   mul

    ==  cmpe

  )},


  list  => sub {[array_keys $_[0]->table()]},

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
      : push    @out,$fn->($x)
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

sub flagchk($anima,$flagref,$ivref) {

  my (@chk)=$anima->get_flags(@$flagref);

    map {
      $chk[$ARG] =! $chk[$ARG]
      if $ivref->[$ARG]

    } 0..$#chk;

  return int grep {$ARG} @chk;

};

# ---   *   ---   *   ---
# conditional load

sub cld($self,$type,$src,@flag) {


  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};

  # negate flag?
  my @iv  = ivflag \@flag;
  my @src = asval $src;


  # make F
  sub ($x) {

    my $y   = shift @src;
    my $chk = flagchk $anima,\@flag,\@iv;

    return ($chk) ? $y : $x ;

  };

};

# ---   *   ---   *   ---
# ^icef*ck

sub lz($self,$type,$src) {
  return $self->cld($type,$src,'zero');

};

sub lnz($self,$type,$src) {
  return $self->cld($type,$src,'nzero');

};

sub lg($self,$type,$src) {
  return $self->cld($type,$src,'great');

};

sub lgz($self,$type,$src) {
  return $self->cld($type,$src,'great','zero');

};

sub ll($self,$type,$src) {
  return $self->cld($type,$src,'less');

};

sub llz($self,$type,$src) {
  return $self->cld($type,$src,'less','zero');

};

# ---   *   ---   *   ---
# loads segment idex to chan

sub load_chan($self,$type) {


  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};
  my $chan  = $anima->{chan};

  # make F
  sub ($x) {
    $chan->store($x);
    return;

  };

};

# ---   *   ---   *   ---
# ^ipret v; sets search path

sub set_scope($self,$main,$src) {

  # get ctx
  my $mc    = $self->getmc();
  my $frame = $mc->{cas}->{frame};
  my $eng   = $main->{engine};

  # need to make copy?
  $src={%$src} if is_hashref $src;


  # make F
  my $out=sub {

    # deref
    $eng->opera_static([$src],1);

    # ^fetch segment and make current
    my $seg=$frame->ice($src->{seg});
    $mc->scope($seg->{value});

  };

  $out->();
  return $out;

};

# ---   *   ---   *   ---
# exclusive OR

sub xor($self,$type,$src) {
  my @src=asval $src;
  sub ($x) {$x ^ shift @src};

};

# ---   *   ---   *   ---
# addition

sub add($self,$type,$src) {
  my @src=asval $src;
  sub ($x) {$x + shift @src};

};

# ---   *   ---   *   ---
# substraction

sub _sub($self,$type,$src) {
  my @src=asval $src;
  sub ($x) {$x - shift @src};

};

# ---   *   ---   *   ---
# multiplication

sub mul($self,$type,$src) {
  my @src=asval $src;
  sub ($x) {$x * shift @src};

};

# ---   *   ---   *   ---
# set insptr

sub jmp($self,$type) {

  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};
  my $rip   = $anima->{rip};

  # ^write to rip
  sub ($x) {
    $rip->store($x,deref=>0);
    return;

  };

};

# ---   *   ---   *   ---
# ^conditional

sub cjmp($self,$type,@flag) {


  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};
  my $rip   = $anima->{rip};

  # negate flag?
  my @iv=ivflag \@flag;

  # make F
  sub ($x) {

    my $chk=flagchk $anima,\@flag,\@iv;
    $rip->store($x,deref=>0) if $chk;

    return;

  };

};

# ---   *   ---   *   ---
# ^icef*ck

sub jz($self,$type) {
  return $self->cjmp($type,'zero');

};

sub jnz($self,$type) {
  return $self->cjmp($type,'nzero');

};

sub jg($self,$type) {
  return $self->cjmp($type,'great');

};

sub jgz($self,$type) {
  return $self->cjmp($type,'great','zero');

};

sub jl($self,$type) {
  return $self->cjmp($type,'less');

};

sub jlz($self,$type) {
  return $self->cjmp($type,'less','zero');

};

# ---   *   ---   *   ---
# jump to F

sub call($self,$type) {

  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};
  my $rip   = $anima->{rip};

  # make F
  my $jump=$self->jump($type);
  my $push=$self->_push(typefet 'qword');

  sub ($x) {

    my $pos=$rip->load(deref=>0);

    $push->($pos);
    $jump->($x);

    return;

  };

};

# ---   *   ---   *   ---
# ^get ready!

sub enter($self,$type) {

  # get ctx
  my $mc    = $self->getmc();
  my $stack = $mc->{stack};
  my $sp    = $stack->{ptr};
  my $sb    = $stack->{base};

  # TODO: get frame size!
  my $fsz=0x08;

  # make F
  my $push = $self->_push(typefet 'qword');

  sub {

    return if ! $fsz;


    $push->($sb->load());

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

  # get ctx
  my $mc    = $self->getmc();
  my $stack = $mc->{stack};
  my $sp    = $stack->{ptr};
  my $sb    = $stack->{base};

  # TODO: get frame size!
  my $fsz=0x08;

  # make F
  my $pop = $self->_pop(typefet 'qword');

  sub {

    return if ! $fsz;

    my $x=$sb->load();

    $sp->store($x);
    $sb->store($pop->());

    return;

  };

};

# ---   *   ---   *   ---
# ^come back!

sub ret($self,$type) {

  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};
  my $rip   = $anima->{rip};

  # make F
  my $jump = $self->jump($type);
  my $pop  = $self->_pop(typefet 'qword');

  sub {

    my $x=$pop->();
    $jump->($x);

    return;

  };

};

# ---   *   ---   *   ---
# a syscall in disguise ;>

sub _exit($self,$type) {

  sub ($x) {
    return ('$:LAST;>',$x);

  };

};
# ---   *   ---   *   ---
# compare two values

sub _cmp($self,$type,$src) {


  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};


  # make F
  my @src=asval $src;
  sub ($x) {


    # substract src from dst
    my $y = shift @src;
    my $z = $x-$y;

    # ^derive flags from result
    $anima->set_flags(

      zero  => ! $z,

      great => $z > 0,
      less  => $z < 0,

    );

    return $anima->{flags};

  };

};

# ---   *   ---   *   ---
# ^get equality

sub _eq($self,$type,$src) {


  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};

  # assume values are equal
  my @src=asval $src;
  my $out=1;


  # ^then challenge that assumption ;>
  my $cmp=$self->_cmp($type,$src);
  sub ($x) {

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

  # get ctx
  my $mc    = $self->getmc();
  my $stack = $mc->{stack};

  my $ptr   = $stack->{ptr};
  my $mem   = $stack->{mem};

  sub ($x) {

    my $have  = $ptr->load();
       $have -= $type->{sizeof};

    $ptr->store($have);
    $mem->store($type,$x,$have);

    return;

  };

};

# ---   *   ---   *   ---
# take from stack

sub _pop($self,$type) {

  # get ctx
  my $mc    = $self->getmc();
  my $stack = $mc->{stack};

  my $ptr   = $stack->{ptr};
  my $mem   = $stack->{mem};

  sub {

    my $have = $ptr->load();
    my $x    = $mem->load($type,$have);

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
