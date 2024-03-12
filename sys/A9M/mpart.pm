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

package A9M::mpart;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Arstd::Bytes;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get next free bit-chunk

sub get_free($class,$mask) {
  return (bitscanf ~$mask)-1;

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
1; # ret
