#!/usr/bin/perl
# ---   *   ---   *   ---
# DEPENDENCY TREE
# Literally chicken and egg
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Tree::Dep;
  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

  use parent 'Tree';

# ---   *   ---   *   ---

sub nit($class,$frame,@args) {

  my $tree=Tree::nit($class,$frame,@args);

  $tree->{needs}={};
  $tree->{needed_by}={};

  return $tree;

};

# ---   *   ---   *   ---

sub append($self,$value) {
  $self->{needs}->{$value}=1;

};

sub track($self) {

  my ($root,$depth)=$self->root();

  my @pending=($self);
  while(@pending) {

    $self=shift @pending;

    my $deps=$self->{needs};
    my $tmp={};

    for my $value(keys %$deps) {

      my $dep=$root->branch_in(qr{^$value$});

      next if !$dep;

      $dep->{needed_by}->{$self->{value}}=$self;
      $tmp->{$dep->{value}}=$dep;

    };

    $self->{needs}=$tmp;

    unshift @pending,@{$self->{leaves}};

  };

};

# ---   *   ---   *   ---

sub hier_sort($self) {

#  my ($root,$depth)=$self->root();
#
#  my $i=0;
#  my @tracked=();
#
#  for my $node(@{$root->{leaves}}) {
#
#my $needs=$node->{needs};
#my $needed_by=$node->{needed_by};
#
#
#
#say $node->{value},":\n";
#
#say '  NEED';
#map {say "    $ARG"} keys %{};
#
#say $NULLSTR;
#
#say '  NEEDED BY';
#map {say "    $ARG"} keys %{};
#
#say "_______________________\n";
#
#  };

};

# ---   *   ---   *   ---
1; # ret
