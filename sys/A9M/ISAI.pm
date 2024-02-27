#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ~
# !!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::ISAI;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Chk;
  use Bpack;

  use Arstd::Bytes;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

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
# ^read/store wraps

sub prim_opera($mem,$type,$addr,$gen,@args) {

  # get type
  $type=typefet $type
  or return null;

  # ^generate F
  my $fn=$gen->($type,@args);


  # read value && run operation
  my $src = $mem->load($type,$addr);
  my @src = opera $fn,$src;

  # ^unpack
  map {
    $ARG=$$ARG if is_scalarref($ARG)

  } @src;

  # ^repack!
  my $bytes=Bpack::layas($type,@src);
  $mem->store($type,$bytes,$addr);


  return;

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
