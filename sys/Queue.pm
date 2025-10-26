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
# lib,

# ---   *   ---   *   ---
# deps

package Queue;
  use v5.42.0;
  use strict;
  use warnings;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v1.00.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# constructor

sub new($class) {
  return bless {
    argc  => [],
    argv  => [],
    procs => [],

  },$class;
};


# ---   *   ---   *   ---
# push subs to Q

sub add($self,$fn,@args) {
  push @{$self->{argc}},int(@args);
  push @{$self->{argv}},@args;
  push @{$self->{procs}},$fn;

  return;
};


# ---   *   ---   *   ---
# ^unshift

sub skip($self,$fn,@args) {
  unshift @{$self->{argc}},int(@args);
  unshift @{$self->{argv}},@args;
  unshift @{$self->{procs}},$fn;

  return;
};


# ---   *   ---   *   ---
# ^remove all

sub clear($self) {
  $self->{argc}  = [];
  $self->{argv}  = [];
  $self->{procs} = [];

  return;
};


# ---   *   ---   *   ---
# do next in list

sub get_next($self) {
  my $argc = shift @{$self->{argc}};
  my $fn   = shift @{$self->{procs}};
  my @argv = ();

  while($argc) {
    push @argv,shift @{$self->{argv}};
    $argc--;
  };

  return $fn->(@argv);
};


# ---   *   ---   *   ---
# ops in Q

sub pending($self) {
  return 0 < @{$self->{procs}}
};


# ---   *   ---   *   ---
# do if anything left to do

sub ex($self) {
  my $out=undef;

  $out=$self->get_next()
  if 0 < @{$self->{procs}};

  return $out;
};


# ---   *   ---   *   ---
# ^do WHILE ;>

sub wex($self) {
  my @out=();

  push @out,$self->get_next()
  while 0 < @{$self->{procs}};

  return @out;
};


# ---   *   ---   *   ---
# ^methods added to Q from
# within the Q itself will
# not be executed

sub immwex($self) {
  my @out     = ();
  my @pending = @{$self->{procs}};

  push @out,$self->get_next()
  for 0..$#pending;

  return @out;
};


# ---   *   ---   *   ---
1; # ret
