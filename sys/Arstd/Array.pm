#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD ARRAY
# Common array operations
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd::Array;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys';
  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    array_nth
    array_keys
    array_values

    array_lshift
    array_rshift

    array_filter
    array_dupop
    array_insert

    array_key_idex

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  my $NO_BLANKS=sub {

     defined $ARG
  && length  $ARG

  };

# ---   *   ---   *   ---
# constructor

sub nit($class,@values) {
  return bless [@values],$class;

};

# ---   *   ---   *   ---
# give every nth elem in array

sub nth($ar,$n,$i) {

  my @slice=@$ar;
  @slice=(@slice[$i..$#slice]);

  $i=0;

  my $matches=[

    (shift @slice),
    grep {!( ++$i % $n)} @slice

  ];

  $matches//=[];
  return @$matches;

};

# ^an alias
# gives @keys where [key=>value,key=>value]

sub nkeys($ar) {return (nth($ar,2,0))};

# ^another alias
# gives @values where [key=>value,key=>value]

sub nvalues($ar) {return (nth($ar,2,1))};

# ---   *   ---   *   ---
# shifts every element to the left from idex

sub lshift($ar,$idex) {

  my @out=($ar->[$idex]);
  my $max=@{$ar}-1;

  while($idex<@$ar-1) {
    $ar->[$idex]=$ar->[$idex+1];
    $idex++;

  };

  push @out,pop @{$ar};
  return @out;

};

# ---   *   ---   *   ---
# ^inverse

sub rshift($ar,$idex) {

  my @out=($ar->[$idex]);

  while($idex>0) {
    $ar->[$idex]=$ar->[$idex-1];
    $idex--;

  };

  push @out,shift @$ar;
  return @out;

};

# ---   *   ---   *   ---
# discards blanks in array

sub filter($ar,$block=undef) {

  $block//=$NO_BLANKS;
  @$ar=grep {$block->($ARG)} @$ar;

};

# ---   *   ---   *   ---
# liminates repeats

sub dupop($ar) {

  my %tmp = ();
  my $i   = 0;

  for my $x(@$ar) {
    $tmp{$x}=(exists $tmp{$x})
      ? $tmp{$x}
      : $i++
      ;

  };

  @$ar=();

  for my $x(keys %tmp) {
    $ar->[$tmp{$x}]=$x;

  };

};

# ---   *   ---   *   ---
# appends subarray at position

sub insert($ar,$pos,@ins) {

  my @ar=@$ar;

  my @head=();
  my @tail=();

  if($pos>0) {
    @head=@ar[0..$pos-1];

  };

  if($pos<$#ar) {
    @tail=@ar[$pos+1..$#ar];

  };

  @$ar=(@head,@ins,@tail);

};

# ---   *   ---   *   ---
# makes {key=>idex} from [keys]

sub key_idex($ar) {
  my $i=0;
  return {map {$ARG=>$i++} @$ar};

};

# ---   *   ---   *   ---
# exporter stuff

  *array_nth      = *nth;
  *array_keys     = *nkeys;
  *array_values   = *nvalues;

  *array_lshift   = *lshift;
  *array_rshift   = *rshift;

  *array_filter   = *filter;
  *array_dupop    = *dupop;
  *array_insert   = *insert;

  *array_key_idex = *key_idex;

# ---   *   ---   *   ---
1; # ret
