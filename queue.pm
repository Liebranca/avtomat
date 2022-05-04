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
# global state

my %CACHE=(

  -DATA=>[],
  -PROCS=>[],

  -QUEUE=>[],

);

# ---   *   ---   *   ---
# getters

sub DATA {return $CACHE{-DATA};};
sub PROCS {return $CACHE{-PROCS};};
sub QUEUE {return $CACHE{-QUEUE};};

sub pending {return int(@{QUEUE()})!=0;};

# ---   *   ---   *   ---

sub add {

  my $proc=shift;
  my @data=@_;

  push @{QUEUE()},int(@data);
  push @{PROCS()},$proc;
  push @{DATA()},@data;

};

# ---   *   ---   *   ---

sub get_next {

  my $argc=shift @{QUEUE()};
  my $proc=shift @{PROCS()};

  my @args=();while($argc) {
    push @args,shift @{DATA()};
    $argc--;

  };$proc->(@args);

};

# ^branchless "do if anything left to do"
sub ex {
  (sub {;},\&get_next)[pending()]->();

};

# ---   *   ---   *   ---
1; # ret
