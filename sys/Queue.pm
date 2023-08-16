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

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION=v1.00.4;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class) {

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

  my @argv=();

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

  if(0 < @{$self->{procs}}) {
    $out=$self->get_next();

  };

  return $out;

};

# ---   *   ---   *   ---
# ^do WHILE ;>

sub wex($self) {

  my @out=();

  while(0 < @{$self->{procs}}) {
    push @out,$self->get_next();

  };

  return @out;

};

# ---   *   ---   *   ---
# ^methods added to Q from
# within the Q itself will
# not be executed

sub immwex($self) {

  my @out     = ();
  my @pending = @{$self->{procs}};

  map {
    push @out,$self->get_next();

  } 0..$#pending;

  return @out;

};

# ---   *   ---   *   ---
1; # ret
