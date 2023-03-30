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

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    mchr
    mord
    lmord

    pastr

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# multi-byte ord
# won't go over a quadword

sub mord($str,%O) {

  # defaults
  $O{width}//=8;
  $O{elem_sz}//=64;
  $O{rev}//=1;

  $str=reverse $str if $O{rev};

  my $word=0;
  my $b=0;

  for my $c(split $NULLSTR,$str) {
    $word|=ord($c)<<$b;$b+=$O{width};
    last if $b==$O{elem_sz};

  };

  return $word;

};

# ---   *   ---   *   ---
# ^fixes that problem
# by handling you a quadword array ;>

sub lmord($str,%O) {

  # defaults
  $O{width}//=8;
  $O{elem_sz}//=64;
  $O{rev}//=1;

  $str=reverse $str if $O{rev};

  my @words=(0);
  my $b=0;

  for my $c(split $NULLSTR,$str) {
    $words[-1]|=ord($c)<<$b;$b+=$O{width};
    if($b==$O{elem_sz}) {push @words,0;$b=0};

  };

  return @words;

};

# ---   *   ---   *   ---
# multi-byte chr
# assumes array of quadwords

sub mchr($data,%O) {

  # defaults
  $O{width}//=8;
  $O{elem_sz}//=64;
  $O{rev}//=0;

  @$data=reverse @$data if $O{rev};

  my $str=$NULLSTR;
  my $word=shift @$data;

  my $b=0;
  my $mask=(1<<$O{width})-1;

  while($word || @$data) {

    $str.=chr($word & $mask);
    $word=$word>>$O{width};

    $b+=$O{width};
    if($b==$O{elem_sz}) {$word=shift @$data;$b=0};

  };

  return $str;

};

# ---   *   ---   *   ---
# encodes strings the boring way

sub pastr($s,%O) {

  # default
  $O{size}  //= 'C';
  $O{width} //= 'C';

  my $len  = length $s;
  my @bs   = lmord($s,rev=>0,elem_sz=>8);

  my $fmat = "$O{size}$O{width}$len";

  return pack $fmat,$len,@bs;

};

# ---   *   ---   *   ---
1; # ret
