#!/usr/bin/perl
# ---   *   ---   *   ---
# PTR
# A location in memory
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Ptr;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Bytes;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {
  return {

    -memref=>undef,
    -types=>undef,

  }};

# ---   *   ---   *   ---
# lock pointer onto the set address

sub point($self) {

  my $memref=$self->{frame}->{-memref};
  my $offset=$self->{offset};

  my $type=(defined $self->{casted})
    ? $self->{casted}
    : $self->{type}
    ;

  my $types=$self->{frame}->{-types};
  my $word_sz=$types->{word}->{size};

# ---   *   ---   *   ---

  my @elems=();

  # is struct
  if(@{$type->{fields}}) {
    @elems=(@{
      $type->{fields}

  }) x $self->{instance_cnt};

  # is primitive
  } else {

    @elems=(
      $type->{size},
      $type->{name},

    ) x $self->{instance_cnt};

  };

# ---   *   ---   *   ---

  for my $i(0..$self->{instance_cnt}-1) {

    my $bn=$self->{by_name}->[$i]={};

    for my $j(0..$type->{elem_count}-1){

      my $size=shift @elems;
      my $name=shift @elems;

      # point to section in mem
      my $idex=$j+($i*$type->{elem_count});
      $self->{buff}->[$idex]=\(vec(

        $$memref,
        int(($offset/$size)+0.9999),$size*8

      ));

      # save by-name access
      $bn->{$name}=$self->{buff}->[$idex];

      # go to next chunk
      $offset+=$size;

    };

  };

# ---   *   ---   *   ---
# pad out the size to halves

  $self->{buff_sz}=int(

    (($offset-$self->{offset})/$word_sz)+0.9999

  );

  $self->{buff_sz}+=$self->{buff_sz}&0b1;

};

# ---   *   ---   *   ---
# constructor

sub nit(

  # implicit
  $class,$frame,

  # actual
  $name,
  $type,
  $offset,
  $cnt,

) {

  my $ptr=bless {

    type=>$type,
    casted=>undef,

    offset=>$offset,
    instance_cnt=>$cnt,

    # by-index access
    buff=>[],
    buff_sz=>0,

    # by-name access
    by_name=>[],

    frame=>$frame,

  },$class;

  $ptr->point();
  $frame->{$name}=$ptr;

  return $ptr;

};

# ---   *   ---   *   ---

sub buf($self,$idex=undef) {

  if(!defined $idex) {
    return @{$self->{buff}};

  } else {
    return $self->{buff}->[$idex];

  };

};

# ---   *   ---   *   ---
# flood fill word-sized chunks

sub flood($self,$value) {

  my $memref=$self->{frame}->{-memref};
  my $types=$self->{frame}->{-types};

  my $word_sz=$types->{word}->{size};
  my $offset=$self->{offset}/$word_sz;

  for my $half(0..$self->{buff_sz}-1) {
    vec($$memref,$offset,64)=$value;
    $offset++;

  };

};

# ---   *   ---   *   ---

sub setv($self,@data) {

  my $i=0;

  while(

     defined $self->{buff}->[$i]
  && defined $data[$i]

  ) {

    ${$self->{buff}->[$i]}=$data[$i];
    $i++;

  };

};

# ---   *   ---   *   ---
# writes a string to memory

sub strcpy($self,$data,%O) {

  # defaults
  $O{wide}//=0;
  $O{disp}//=0;

# ---   *   ---   *   ---

  my $sz=8+(8*$O{wide});
  my @chars=lmord(

    $data,

    width=>$sz,
    elem_sz=>$sz,

    rev=>0

  );

# ---   *   ---   *   ---

  my $memref=$self->{frame}->{-memref};
  my $offset=$self->{offset};

  $offset+=$O{disp};

  for my $c(@chars) {
    vec($$memref,$offset++,$sz)=$c;

  };

};

# ---   *   ---   *   ---
# returns a slice of pointed memory

sub rawdata($self,%O) {

  # defaults
  $O{beg}//=0;
  $O{end}//=-1;

  my $memref=$self->{frame}->{-memref};
  my $offset=$self->{offset};

  my $types=$self->{frame}->{-types};
  my $word_sz=$types->{word}->{size};

  my $size;

  # full read
  if($O{beg}==0 && $O{end}<0) {
    $size=$self->{buff_sz}*$word_sz;

  # partial read
  } else {

    my $elem_sz=$self->{type}->{size};

    $offset+=$O{beg}*$elem_sz;
    $size=($O{end}-$O{beg})*$elem_sz;

  };

  return substr $$memref,$offset,$size;

};

# ---   *   ---   *   ---
1; # ret
