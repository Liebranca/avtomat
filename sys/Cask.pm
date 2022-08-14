#!/usr/bin/perl
# ---   *   ---   *   ---
# Cask
# Array that reuses vacant slots
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Cask;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::IO;

# ---   *   ---   *   ---
# info

  our $VERSION=v1.00.3;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $SENTINEL=>[0x5E4714E7];

  Readonly our $FIRST_AVAIL=>[0x10577A4E];
  Readonly our $FIRST_FREE=>[0x10575107];

# ---   *   ---   *   ---

sub nit($class,@data) {

  my $i=0;
  return bless [map {$i++=>$ARG} @data],$class;

};

# ---   *   ---   *   ---
# add value

sub give($self,$value) {

  my %h=reverse @$self;
  my $avail=$h{$SENTINEL};

  if(!defined $avail) {
    $avail=@$self>>1;
    push @$self,$avail=>$value;

  } else {
    $self->[($avail<<1)+1]=$value;

  };

  return $avail;

};

# ---   *   ---   *   ---
# get value and replace

sub take(

  # implicit
  $self,

  # actual
  $idex=$FIRST_AVAIL,
  $value=$SENTINEL

) {

  my $out=undef;

  # get any
  if($idex eq $FIRST_AVAIL) {
    $idex=(grep {

      defined $ARG && $ARG ne $SENTINEL

    } array_values($self))[0];


    # catch none avail
    errout(

      q{Take from empty cask},
      lvl=>$AR_WARNING

    ) && goto TAIL unless defined $idex;

  };

# ---   *   ---   *   ---

  # get by index
  if($idex=~ m[^[\d]+$]) {
    $idex=($idex<<1)+1;

  # get by value
  } else {
    my %h=reverse @$self;
    $idex=($h{$idex}<<1)+1;

  };

  # replace
  $out=$self->[$idex];
  $self->[$idex]=$value;

# ---   *   ---   *   ---

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# ^just get value

sub view($self,$idex) {

  if($idex=~ m[^[\d]+$]) {
    $idex=($idex<<1)+1;

  } else {
    my %h=reverse @$self;
    $idex=($h{$idex}<<1)+1;

  };

  return $self->[$idex];

};

# ---   *   ---   *   ---

sub empty($self) {

  my $x=int(grep {

    !defined $ARG || $ARG eq $SENTINEL

  } array_values($self));

  return $x == int(@$self)>>1;

};

# ---   *   ---   *   ---
1; # ret
