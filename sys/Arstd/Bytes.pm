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
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd::Bytes;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    mchr
    mord
    lmord

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# multi-byte ord
# won't go over a quadword

sub mord($str,$width=8) {

  my $word=0;
  my $b=0;

  for my $c(reverse split $NULLSTR,$str) {
    $word|=ord($c)<<$b;$b+=$width;
    last if $b==64;

  };

  return $word;

};

# ---   *   ---   *   ---
# ^fixes that problem
# by handling you a quadword array ;>

sub lmord($str,$width=8) {

  my @words=(0);
  my $b=0;

  for my $c(reverse split $NULLSTR,$str) {
    $words[-1]|=ord($c)<<$b;$b+=$width;
    if($b==64) {push @words,0;$b=0};

  };

  return @words;

};

# ---   *   ---   *   ---
# multi-byte chr
# assumes array of quadwords

sub mchr($data,$width=8) {

  my $str=$NULLSTR;
  my $word=shift @$data;

  my $b=0;
  my $mask=(1<<$width)-1;

  while($word || @$data) {

    $str.=chr($word & $mask);
    $word=$word>>$width;

    $b+=$width;
    if($b==64) {$word=shift @$data;$b=0};

  };

  return $str;

};

# ---   *   ---   *   ---
1; # ret
