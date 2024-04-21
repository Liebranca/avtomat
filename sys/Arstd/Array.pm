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

  use Carp;
  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys';

  use Chk;
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
    array_sort
    array_lsort

    array_iof
    array_wrap
    array_flatten

    array_vmap
    array_kmap
    array_map

    array_matchpop

    IDEXUP
    IDEXUP_P2

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.9;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $NO_BLANKS=>sub {

     defined $ARG
  && length  $ARG

  };

# ---   *   ---   *   ---
# cstruc

sub new($class,@values) {
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
  return grep {$ARG} @$matches;

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

  map {

    $tmp{$ARG}=(! exists $tmp{$ARG})
      ? [$i++,$ARG]
      : $tmp{$ARG}
      ;

  } @$ar;


  @$ar=();

  map {
    my ($idex,$value)=@$ARG;
    $ar->[$idex]=$value;

  } values %tmp;

  return;

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
# sorts by value

sub nsort($ar) {
  @$ar=sort {$b<=>$a} @$ar;

};

# ---   *   ---   *   ---
# ^sorts by length

sub nlsort($ar) {

  @$ar=sort {

    (length $b)<=>(length $a);

  } @$ar;

};

# ---   *   ---   *   ---
# give idex of element

sub iof($ar,$elem) {

  croak 'iof: undefined elem'
  if ! defined $elem;


  my ($idex)=grep {
    $ar->[$ARG] eq $elem

  } 0..int(@$ar)-1;

  return $idex;

};

# ---   *   ---   *   ---
# wrapping indexing into array

sub wrap($ar,$idex) {
  $idex=$idex % @$ar;
  return $ar->[$idex];

};

# ---   *   ---   *   ---
# recursively flatten array
# gives copy!

sub flatten($ar,%O) {

  # defaults
  $O{dupop} //= 0;


  # walk
  my @out = ();
  my @Q   = @$ar;

  while(@Q) {

    # recurse if stepped on array
    # else copy value to dst
    my $chd=shift @Q;
    (is_arrayref($chd))
      ? unshift @Q,@$chd
      : push    @out,$chd
      ;

  };


  # clear duplicates?
  dupop(\@out) if $O{dupop};

  # give copy
  return @out;

};

# ---   *   ---   *   ---
# array as hash walk proto

sub nmap($ar,$fn,$mode='ikv') {


  # we overwrite these values on walk step
  my $k=0;
  my $v=0;
  my $i=0;

  # ^and access configurations of them
  my $tab={


    # default mode: Illya Kuryaki && the Valderramas
    ikv => [\$i,\$k,\$v],


    # [key,value]
    kv  => [\$k,\$v],

    # [idex,key],[idex,value]
    ik  => [\$i,\$k],
    iv  => [\$i,\$v],

    # [idex],[key],[value],
    i   => [\$i],
    k   => [\$k],
    v   => [\$v],

  };


  # decompose array
  my $ni=0;
  my @nk=nkeys($ar);
  my @nv=nvalues($ar);

  # ^walk
  map {

    # overwrite refs
    $k = \$ARG;
    $v = \$nv[$ni];
    $i = $ni++;

    # ^get arg config and give call
    my $args=$tab->{$mode};
    $fn->(map {$$ARG} @$args);


  } @nk;

};

# ---   *   ---   *   ---
# ^icebox

sub kmap($ar,$fn) {
  nmap($ar,$fn,'k');

};

sub vmap($ar,$fn) {
  nmap($ar,$fn,'v');

};

# ---   *   ---   *   ---
# consume elements as they match
# against a re sequence
#
# returns (all-matched,matches)

sub matchpop($ar,@seq) {

  return (0,()) if @$ar < @seq;


  my $idex  = 0;
  my @match = map {
    $ar->[$idex++]=~ $ARG

  } @seq;

  return (@match == @seq,@match);

};

# ---   *   ---   *   ---
# ~

sub IDEXUP($idex,$f,@list) {
  return map {$f->($ARG,$idex++)} @list;

};

sub IDEXUP_P2($idex,$f,@list) {
  return map {$f->($ARG,1 << $idex++)} @list;

};

# ---   *   ---   *   ---
# exporter names

  *array_nth      = *nth;
  *array_keys     = *nkeys;
  *array_values   = *nvalues;

  *array_lshift   = *lshift;
  *array_rshift   = *rshift;

  *array_filter   = *filter;
  *array_dupop    = *dupop;
  *array_insert   = *insert;

  *array_key_idex = *key_idex;
  *array_sort     = *nsort;
  *array_lsort    = *nlsort;

  *array_iof      = *iof;
  *array_wrap     = *wrap;
  *array_flatten  = *flatten;

  *array_vmap     = *vmap;
  *array_kmap     = *kmap;
  *array_map      = *nmap;

  *array_matchpop = *matchpop;

# ---   *   ---   *   ---
1; # ret
