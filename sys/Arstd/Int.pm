#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD INT
# Common numerical problems
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::Int;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use Arstd::Bytes qw(bitscanr);

  use lib "$ENV{ARPATH}/lib/sys";
  use parent 'St';


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';

  our @EXPORT=qw(
    int_urdiv
    int_align
    int_npow
    int_npow2
    int_ispow

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# cstruc

sub new($class,$value) {
  return bless \$value,$class;

};


# ---   *   ---   *   ---
# divide and round up

sub urdiv($a,$b) {
  return int((abs($a)/$b)+0.9999);

};


# ---   *   ---   *   ---
# ^force A to nearest multiple of B

sub align($a,$b) {
  return urdiv($a,$b) * $b;

};


# ---   *   ---   *   ---
# ^force A to nearest pow of B

sub npow($a,$b,$give_exp=0) {
  my $x=int(log $a**$b)-1;
  return ($give_exp) ? $x : $b**$x;

};


# ---   *   ---   *   ---
# ^get A is pow B

sub ispow($a,$b) {

  return 0 if ! $a ||! $b;


  my $x=log($a);
  my $y=log($b);
  my $z=$x/$y;

  return ($z-int $z) ? 0 : $z;

};


# ---   *   ---   *   ---
# nearest power of 2
# this is the only precise one ;>

sub npow2($a,$give_exp=0) {

  my $x    = bitscanr $a;
  my $mask = $x-1;

  $x++ while (1 << $x) < $a;


  return ($give_exp) ? $x : 1 << $x;

};


# ---   *   ---   *   ---
# exporter names

  *int_urdiv = *urdiv;
  *int_align = *align;
  *int_npow  = *npow;
  *int_npow2 = *npow2;
  *int_ispow = *ispow;


# ---   *   ---   *   ---
1; # ret
