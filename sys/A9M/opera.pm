#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M OPERA
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

package A9M::opera;

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

  use Arstd::Bytes;
  use Arstd::Array;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  table => [


    # imm/mem/reg to reg
    load => {

      fn       => 'copy',
      load_dst => 0,

      dst      => 'r',
      src      => 'rmi',

    },

    # reg to mem
    store => {

      fn       => 'copy',
      load_dst => 0,

      dst      => 'm',
      src      => 'r',

    },

  #  # our beloved
  #  # load effective address ;>
  #  lea => {
  #
  #    load_dst => 0,
  #    load_src => 0,
  #
  #    dst      => 'r',
  #    src      => 'm',
  #
  #  },
  #
  #
  #  # bitops
  #  xor => {
  #    dst  => 'r',
  #    src  => 'ri',
  #
  #  },
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
  #  # math
  #  add => {
  #    dst  => 'r',
  #    src  => 'ri',
  #
  #  },
  #
  #  sub => {
  #    dst  => 'r',
  #    src  => 'ri',
  #
  #  },
  #
  #
  #  mul => {
  #    dst  => 'r',
  #    src  => 'r',
  #
  #  },
  #
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
  #
  #  # stack ctl
  #  push => {
  #
  #    dst       => 'rmi',
  #    argcnt    => 1,
  #    overwrite => 0,
  #
  #    fix_size  => ['qword'],
  #
  #  },
  #
  #  pop => {
  #
  #    dst       => 'r',
  #    argcnt    => 1,
  #    overwrite => 1,
  #
  #    load_dst  => 0,
  #    fix_size  => ['qword'],
  #
  #  },
  #
  #
  #  # control flow
  #  jmp => {
  #
  #    argcnt => 1,
  #    dst    => 'rmi',
  #
  #    overwrite => 0,
  #    fix_size  => ['qword'],
  #
  #  },
  #
  #  call => {
  #
  #    argcnt    => 1,
  #    dst       => 'rmi',
  #
  #    overwrite => 0,
  #    fix_size  => ['qword'],
  #
  #  },
  #
  #  ret => {
  #    argcnt=>0,
  #
  #  },


  ],


  list  => sub {[array_keys $_[0]->table()]},

};

# ---   *   ---   *   ---
# run generic op on value

sub opera($fn,$value) {

  my @out = ();
  my @Q   = $value;

  while(@Q) {

    my $x=shift @Q;

    (is_arrayref($x))
      ? unshift @Q,@$x
      : push    @out,$fn->($x)
      ;

  };


  return @out;

};

# ---   *   ---   *   ---
# ^external version

sub copera($class,$fn,$value) {
  opera $fn,$value;

};

# ---   *   ---   *   ---
# make prim from vector elems

sub flatten($class,$ezy,$bits=undef) {

  $bits //= $ezy;

  my $out=0x00;
  my $cnt=0x00;

  sub ($x) {

    if($cnt == $bits) {
      $out=0x00;
      $cnt=0x00;

    };


    $out |= $x << $cnt;
    $cnt += $ezy;

    ($cnt == $bits) ? $out : () ;

  };

};

# ---   *   ---   *   ---
# give src as-is

sub copy($class,$type,$args) {
  $args->[1];

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
1; # ret
