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
  use strict;
  use warnings;

# ---   *   ---   *   ---
# getters

sub argc {return (shift)->{-ARGC};};
sub argv {return (shift)->{-ARGV};};

sub procs {return (shift)->{-PROCS};};

sub pending {

  my $self=shift;
  return int(@{$self->procs()})!=0;

};

# ---   *   ---   *   ---
# constructor

sub nit {

  return bless {

    -ARGC=>[],
    -ARGV=>[],

    -PROCS=>[],

  },'queue';

};

# ---   *   ---   *   ---

sub add {

  my $self=shift;

  my $proc=shift;
  my @argv=@_;

  push @{$self->argc()},int(@argv);
  push @{$self->argv()},@argv;

  push @{$self->procs()},$proc;

};sub clear {

  my $self=shift;

  $self->{-ARGC}=[];
  $self->{-ARGV}=[];
  $self->{-PROCS}=[];

};

# ---   *   ---   *   ---

sub get_next {

  my $self=shift;

  my $argc=shift @{$self->argc()};
  my $proc=shift @{$self->procs()};

  my @argv=();while($argc) {
    push @argv,shift @{$self->argv()};
    $argc--;

  };$proc->(@argv);

};

# ^branchless "do if anything left to do"
sub ex {

  my $self=shift;

  (sub {;},\&get_next)
  [$self->pending()]->($self);

};

# ---   *   ---   *   ---
1; # ret
