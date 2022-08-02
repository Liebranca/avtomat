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
  use Arstd;

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
  my $half_sz=$types->{half}->{size};

# ---   *   ---   *   ---

  my @elems=();

  # is struct
  if(@{$type->{fields}}) {
    @elems=(@{$type->{fields}});

  # is primitive
  } else {

    @elems=(
      $type->{size},
      $type->{name},

    ) x $self->{instance_cnt};

  };

# ---   *   ---   *   ---

  for my $i(0..$self->{instance_cnt}-1) {
    for my $j(0..$type->{elem_count}-1){

      my $size=shift @elems;
      my $name=shift @elems;

      my $idex=$j+($i*$type->{elem_count});
      $self->{buff}->[$idex]=\(vec(

        $$memref,
        int(($offset/$size)+0.9999),$size*8

      ));

      $offset+=$size;

    };

  };

# ---   *   ---   *   ---
# pad out the size to halves

  $self->{buff_sz}=int(

    (($offset-$self->{offset})/$half_sz)+0.9999

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

    buff=>[],
    buff_sz=>0,

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
# flood fill half-sized chunks

sub flood($self,$value) {

  my $memref=$self->{frame}->{-memref};
  my $types=$self->{frame}->{-types};

  my $half_sz=$types->{half}->{size};
  my $offset=$self->{offset}/$half_sz;

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
1; # ret
