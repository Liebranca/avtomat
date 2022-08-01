#!/usr/bin/perl
# ---   *   ---   *   ---
# PTR
# A scope within memory
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

  sub Frame_Vars($class) {{
    memref=>undef,

  }};

# ---   *   ---   *   ---
# lock pointer onto the set address

sub point($self) {

  my $memref=$self->{frame}->{memref};
  my $offset=$self->{offset};

say $self->{elem_cnt};
say $self->{elem_sz};

  for my $i(0..$self->{elem_cnt}-1) {

    $self->{buff}->[$i]=\(vec(

      $$memref,

      $offset,
      $self->{elem_sz}*8

    ));

    $offset++;

  };

};

# ---   *   ---   *   ---
# constructor

sub nit(

  # passed implicitly
  $class,$frame,

  # actual args
  $offset,
  $elem_cnt,
  $elem_sz,

) {

  my $ptr=bless {

    casted=>undef,

    elem_cnt=>$elem_cnt,
    elem_sz=>$elem_sz,

    offset=>$offset,
    buff=>[],

    frame=>$frame,

  },$class;

  $ptr->point();

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

sub flood($self,$value) {

  for my $x(@{$self->{buff}}) {
    $$x=0;

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
