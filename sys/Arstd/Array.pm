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
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::Array;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_arrayref);
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    nth
    nkeys
    nvalues

    lshift
    rshift
    nsort
    nlsort
    nmap

    filter
    dupop
    insert

    wrap
    flatten
    matchpop

    iof
    rmi
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# cstruc

sub new($class,@values) {
  return bless [@values],$class;
};


# ---   *   ---   *   ---
# give every nth elem in array

sub nth($ar,$n,$i) {
  my @slice=(@$ar)[$i..@$ar-1];
  $i=0;

  my $matches=[
    (shift @slice),
    grep {! (++$i % $n)} @slice
  ];

  $matches//=[];
  return grep {! is_null $ARG} @$matches;
};


# ---   *   ---   *   ---
# ^an alias
# gives @keys where [key=>value,key=>value]

sub nkeys($ar) {return (nth($ar,2,0))};


# ---   *   ---   *   ---
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

sub filter($ar,$block=\&is_null) {
  @$ar=grep {$block->($ARG)} @$ar;
  return;
};


# ---   *   ---   *   ---
# liminates repeats

sub dupop($ar) {
  my %tmp = ();
  my $i   = 0;

  for(@$ar) {
    my $key;
    if(is_arrayref $ARG) {
      $key=join '|',@$ARG;

    } else {
      $key="$ARG";

    };

    $tmp{$key}=(! exists $tmp{$key})
      ? [$i++,$ARG]
      : $tmp{$key}
      ;

  };


  @$ar=();

  for(values %tmp) {
    my ($idex,$value)=@$ARG;
    $ar->[$idex]=$value;

  };

  return;
};


# ---   *   ---   *   ---
# appends subarray at position

sub insert($ar,$pos,@ins) {
  my @ar   = @$ar;
  my @head = ();
  my @tail = ();

  if($pos>0) {
    @head=@ar[0..$pos-1];

  };

  if($pos<$#ar) {
    @tail=@ar[$pos+1..$#ar];

  };

  @$ar=(@head,@ins,@tail);
  return;
};


# ---   *   ---   *   ---
# makes {key=>idex} from [keys]

sub key_idex($ar,$rev=0) {
  my @have=map {
    $ar->[$ARG]=>$ARG

  } 0..@$ar-1;

  @have=reverse @have if $rev;

  return {@have};
};


# ---   *   ---   *   ---
# sorts by value

sub nsort($ar) {
  @$ar=sort {$b<=>$a} @$ar;
  return;
};


# ---   *   ---   *   ---
# ^sorts by length

sub nlsort($ar) {
  @$ar=sort {
    (length $b)<=>(length $a);

  } @$ar;
  return;
};


# ---   *   ---   *   ---
# give idex of element

sub iof($ar,$elem) {
  throw 'iof: undefined elem'
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
    (is_arrayref $chd)
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
# removes element

sub rmi($ar,$elem) {
  # assume that element *is* idex
  my $i=$elem;

  # ^then get element idex if elem is a string ;>
  if(! index $elem,'$') {
    substr $elem,0,1,null;
    $i=iof($ar,$elem);
  };


  throw "rmi '$elem': no such element in array"
  if ! defined $i;

  $ar->[$i]=undef;
  filter($ar);

  return;
};


# ---   *   ---   *   ---
# array as hash walk proto

sub nmap($ar,$fn,$mode='ikv') {
  # we overwrite these values on walk step
  my $k=0;
  my $v=0;
  my $i=0;

  # decompose array
  my $ni=0;
  my @nk=nkeys($ar);
  my @nv=nvalues($ar);

  # ^walk
  return map {
    # overwrite refs
    $k = \$ARG;
    $v = \$nv[$ni];
    $i = $ni++;

    # ^get arg config and give call
    my $args={
      # default mode:
      # ~Illya Kuryaki && the Valderramas~
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

    }->{$mode};

    $fn->(map {$$ARG} @$args);

  } @nk;
};


# ---   *   ---   *   ---
# ^icebox

sub kmap($ar,$fn) {
  return nmap($ar,$fn,'k');
};

sub vmap($ar,$fn) {
  return nmap($ar,$fn,'v');
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
1; # ret
