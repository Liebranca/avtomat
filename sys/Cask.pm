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

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Arstd::Array;

# ---   *   ---   *   ---
# info

  our $VERSION=v1.00.3;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $SENTINEL=[qw(0x5E47 0x14E7)];

# ---   *   ---   *   ---

sub nit($class) {
  return bless [],$class;

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
# replace value

sub take($self,$idex,$value=$SENTINEL) {

  if($idex=~ m[^[\d]+$]) {
    $idex=($idex<<1)+1;

  } else {
    my %h=reverse @$self;
    $idex=($h{$idex}<<1)+1;

  };

  my $out=$self->[$idex];
  $self->[$idex]=$value;

  return $out;

};

# ---   *   ---   *   ---
# get value

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
