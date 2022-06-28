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
package queue;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# info

  our $VERSION=v1.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# getters

sub argc($self) {return $self->{argc}};
sub argv($self) {return $self->{argv}};
sub procs($self) {return $self->{procs}};

sub pending($self) {
  return int(@{$self->procs()})!=0;

};

# ---   *   ---   *   ---
# constructor

sub nit() {

  return bless {

    argc=>[],
    argv=>[],
    procs=>[],

  },'queue';

};

# ---   *   ---   *   ---

sub add($self,$fn,@args) {
  push @{$self->argc()},int(@args);
  push @{$self->argv()},@args;
  push @{$self->procs()},$fn;

  return;

};sub clear($self) {
  $self->{argc}=[];
  $self->{argv}=[];
  $self->{procs}=[];

  return;

};

# ---   *   ---   *   ---
# do next in list

sub get_next($self) {

  my $argc=shift @{$self->argc()};
  my $fn=shift @{$self->procs()};

  my @argv=();

  while($argc) {
    push @argv,shift @{$self->argv()};
    $argc--;

  };

  return $fn->(@argv);

};

# ---   *   ---   *   ---
# do if anything left to do

sub ex($self) {
  my $out=undef;

  if($self->pending) {
    $out=$self->get_next;

  };

  return $out;

};

# ---   *   ---   *   ---
1; # ret
