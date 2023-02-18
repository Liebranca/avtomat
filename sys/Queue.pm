#!/usr/bin/perl
# ---   *   ---   *   ---
# QUEUE
# Why do it now when you
# can do it later?
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Queue;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# info

  our $VERSION=v1.00.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# getters

sub pending($self) {
  return 0 < @{$self->{procs}};

};

# ---   *   ---   *   ---
# constructor

sub nit($class) {

  return bless {

    argc=>[],
    argv=>[],
    procs=>[],

  },$class;

};

# ---   *   ---   *   ---

sub add($self,$fn,@args) {
  push @{$self->{argc}},int(@args);
  push @{$self->{argv}},@args;
  push @{$self->{procs}},$fn;

  return;

};

sub clear($self) {
  $self->{argc}=[];
  $self->{argv}=[];
  $self->{procs}=[];

  return;

};

# ---   *   ---   *   ---
# do next in list

sub get_next($self) {

  my $argc = shift @{$self->{argc}};
  my $fn   = shift @{$self->{procs}};

  my @argv=();

  while($argc) {
    push @argv,shift @{$self->{argv}};
    $argc--;

  };

  return $fn->(@argv);

};

# ---   *   ---   *   ---
# do if anything left to do

sub ex($self) {

  my $out=undef;

  if($self->pending()) {
    $out=$self->get_next();

  };

  return $out;

};

# ---   *   ---   *   ---
# ^do WHILE ;>

sub wex($self) {

  my @out=();

  while($self->pending()) {
    push @out,$self->get_next();

  };

  return @out;

};

# ---   *   ---   *   ---
1; # ret
