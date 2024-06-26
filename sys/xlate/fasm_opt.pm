#!/usr/bin/perl
# ---   *   ---   *   ---
# XLATE FASM OPT
# Simple x86 optimizations
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS,
# lyeb,

# ---   *   ---   *   ---
# deps

package xlate::fasm_opt;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match_vars);

  use lib "$ENV{ARPATH}/avtomat/sys/";

  use Style;
  use Type;

  use Arstd::Int;
  use Arstd::Bytes;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    fxpreci
    fxpdiv
    fxpmod

    leamul

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# mul by lea: first attempt

sub leamul_step1($y,$s,$need) {


  # map opera to instruction
  my $tab={
    "$y+$y*$s" => "lea  Y,[Y+Y*$s];",
    "0+$y*$s"  => "lea  Y,[0+Y*$s];",

  };


  # ^walk
  my @out=();
  map {

    my $res=eval $ARG;

    # stop if single will do
    return ($res,$tab->{$ARG})
    if $res == $need;


    # else give full table
    push @out,$res,$tab->{$ARG};


  } keys %$tab;

  return @out;

};

# ---   *   ---   *   ---
# mul by lea: second attempt

sub leamul_step2($n,$y,$s,$need) {


  # map opera to instruction
  my $tab={

    "$n+$n*$s" => "lea  Y,[N+N*$s];",
    "$n+$y*$s" => "lea  Y,[N+Y*$s];",
    "$y+$y*$s" => "lea  Y,[Y+Y*$s];",
    "$y+$n*$s" => "lea  Y,[Y+N*$s];",

    "0+$n*$s"  => "lea  Y,[0+N*$s];",
    "0+$y*$s"  => "lea  Y,[0+Y*$s];",

    "$n"       => null,
    "$y"       => null,

  };


  map {

    my $res=eval $ARG;

    # stop if two ops will do
    return $tab->{$ARG}
    if $res == $need;

  } keys %$tab;


  # else fail!
  return undef;

};

# ---   *   ---   *   ---
# multiply by non-pow2 using lea
# imul on fail ;>

sub leamul($n,$f) {


  # f is pow2?
  my $p2 = int_npow2 $f,1;
  if((1 << $p2) == $f) {
    return ($n << $p2,"shl  N,$p2;");

  };


  # ^nope, do it the hard way ;>
  my @scale = (2,4,8);
  my @ins   = ();

  my $x     = 0;
  my $need  = $n*$f;


  # walk first row
  for my $s0(@scale) {


    # single op does it?
    my @combo=leamul_step1 $n,$s0,$need;
    if(@combo == 2) {
      $x   = shift @combo;
      @ins = shift @combo;

      last;

    };


    # ^nope, walk second row...
    for my $idex(0..1) {

      my $y    = $combo[$idex*2+0];
      my $ins  = $combo[$idex*2+1];

      for my $s1(@scale) {


        # stop if two ops does it!
        my $have = leamul_step2 $n,$y,$s1,$need;

        if(defined $have) {
          @ins = ($ins,$have);
          $x   = $need;

          last;

        };

      };

      last if $x;

    };


    last if $x;

  };


  # give imul if X wasn't solved
  return ($x == 0)

    ? (

      $need,

      "mov  Z,$f;",
      'imul Y,Z;'

    ) : ($need,@ins) ;

};

# ---   *   ---   *   ---
# fixed point division by
# multiplication
#
# ie black flippin' magic

sub fxpreci($f,$bits) {
  return int (((1<<$bits) + $f-1) / $f);

};

sub fxpdiv($n,$f,$bits=0) {


  # f is pow2?
  my $p2  = int_npow2 $f,1;
  if((1 << $p2) == $f) {
    return ($n >> $p2,"shr  N,$p2;");

  };


  # ^nope, do it the hard way ;>
  $bits=2+bitsize $n if ! $bits;

  my $rc  = fxpreci($f,$bits);
  my @ins = (
    "mov  Y,$rc;",
    'mul  N;',

    "shr  Y,$bits;",

  );

  return (($n * $rc) >> $bits,@ins);

};

# ---   *   ---   *   ---
# ^fixed point modulo

sub fxpmod($n,$f,$bits=0) {


  # f is pow2?
  my $p2  = int_npow2 $f,1;
  if((1 << $p2) == $f) {
    my $mask=$f-1;
    return ($n & $mask,"and  N,$mask;");

  };


  # ^nope, do it the hard way ;>
  $bits=2+bitsize $n if ! $bits;

  my ($x,@insa) = fxpdiv $n,$f,$bits;
  my ($y,@insb) = leamul $x,$f;

  my @ins=(@insa,@insb,'sub  N,Y;');

  return ($n-$y,@ins);

};

# ---   *   ---   *   ---
1; # ret
