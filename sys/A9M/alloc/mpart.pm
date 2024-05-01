#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M MPART
# Simple partitions
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::alloc::mpart;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Warnme;

  use Arstd::Bytes;
  use Arstd::Int;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get next free bit-chunk

sub get_free($class,$mask) {

  my $i   = bitscanf ~$mask;
     $i //= 0;

  return $i-1;

};

# ---   *   ---   *   ---
# ^shift to start

sub shr_free($class,$maskref,$src) {

  my $i=$class->get_free($$maskref);

  $$maskref >>= $i;
  return $i;

};

# ---   *   ---   *   ---
# get next occupied bit-chunk

sub get_occu($class,$mask) {
  bitscanr $mask;

};

# ---   *   ---   *   ---
# ^shift out

sub shr_occu($class,$have,$maskref,$src) {

  my $i=$class->get_occu($have);

  $$maskref >>= $i;
  return $i;

};

# ---   *   ---   *   ---
# fit bitmask into another

sub fit($class,$maskref,$bits,%O) {


  # defaults
  $O{limit} //= 0x40;

  # get pos/max && elem size
  my $pos   = 0;
  my $limit = $O{limit}-$bits;
  my $ezy   = bitmask $bits;


  # save old mask
  my $old=$$maskref;


  # find free bit chunk in mask
  while($pos < $limit) {


    # get next free bit chunk
    $pos += $class->shr_free($maskref,$ezy);

    # chunk big enough?
    my $have=$$maskref & $ezy;
    last if ! $have;


    # ^nope, skip
    $pos += $class->shr_occu(
      $have,$maskref,$ezy

    );

  };


  # update mask and give [ezy,pos] on success
  if($pos <= $limit) {

    $$maskref  = $old;
    $$maskref |= $ezy << $pos;

    return ($ezy,$pos);

  # ^give nothing on fail
  } else {
    return ();

  };

};

# ---   *   ---   *   ---
# determine partition level

sub getlvl($self,$main,$req) {


  # get ctx
  my $cnt   = $main->lvlcnt();
  my $base  = $main->{base};

  my $bits  = $base->{sizebs};
  my $pow   = $main->{pow};


  # add block header size to requested
  my $reqb = $req + $main->blk_t->{sizeof};

  # align requested size to granularity
  my $total = int_align $reqb,$bits;
  my $size  = 0;
  my $lvl   = null;


  for my $i(0..$cnt-1) {


    # get next partition level
    my $ezy = 1 << $pow;
    my $cap = $ezy * $bits;

    # ^total fits within three sub-blocks?
    if($total <= $ezy * 3) {

      $lvl  = $i;
      $size = int $total/$ezy;

      last;

    # ^total fits within maximum size?
    } elsif($i == $cnt-1) {

      $lvl=($total >= $cap)
        ? warn_reqsize($req,$total)
        : $i
        ;

      $size=int $total/$ezy;

      last;

    };


    # go next
    $pow++;

  };


  return ($lvl,$size);


};

# ---   *   ---   *   ---
# ^errme

sub warn_reqsize($req,$total) {

  warnproc

    'block of size $[num]:%X '
  . '(requested: $[num]:%X) '

  . 'exceeds maximum partition size',

  args => [$total,$req],
  give => null;

};

# ---   *   ---   *   ---
1; # ret
