#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD BYTES
# Bit hacking stravaganza
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::Bytes;
  use v5.42.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;
  use Module::Load;

  use English;
  use List::Util qw(max min);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    bitsize
    bitmask
    bitscanf
    bitscanr

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.9';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# get bitsize of number

sub bitsize($x) {

  my $out=0;
  my $bit=1;
  my $set=0;

  while($x) {

    $set   = $bit * ($x & 1);
    $out   = ($set) ? $set : $out;

    $x   >>= 1;

    $bit++;

  };

  return (! $out) ? 1 : $out;

};


# ---   *   ---   *   ---
# ^get a bitmask for n number of bits

sub bitmask($x) {
  return (1 << $x)-1;

};


# ---   *   ---   *   ---
# bsf -- if you know, you know ;>

sub bitscanf($x) {
  my $idex=1;
  my $have=undef;

  while($x) {
    ($have)=($idex),last if $x & 1;

    $x >>= 1;
    ++$idex;
  };
  return $have;
};


# ---   *   ---   *   ---
# ^bsr

sub bitscanr($x) {
  my $idex=64;
  my $have=undef;

  while($idex--) {
    ($have)=($idex),last
    if $x & (1 << $idex);

  };

  return $have;

};


# ---   *   ---   *   ---
# div bitsize by 8, rounded up

sub bytesize($x) {
  my $bits=bitsize $x;
  return int(($bits/8)+0.9999);

};


# ---   *   ---   *   ---
1; # ret
