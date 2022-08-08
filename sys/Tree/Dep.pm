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

# ---   *   ---   *   ---

sub track($self) {

  my ($root,$depth)=$self->root();

  my @pending=($root);
  while(@pending) {

    $self=shift @pending;

    my $deps=$self->{needs};
    my $tmp={};

    for my $value(keys %$deps) {

      my $dep=$root->branch_in(qr{^$value$});

      next if !$dep || $dep eq $self;

      $dep->{needed_by}->{$self->{value}}=$self;
      $tmp->{$dep->{value}}=$dep;

    };

    $self->{needs}=$tmp;

    unshift @pending,@{$self->{leaves}};

  };

# ---   *   ---   *   ---

  $root->hier_sort();
  return $root->list_by_priority();

};

# ---   *   ---   *   ---

sub hier_sort($self) {

  my ($root,$depth)=$self->root();

  my $i=0;

  my @tracked=();
  my @pending=(@{$root->{leaves}});

  for my $node(@pending) {

    my $needs=$node->{needs};
    my $needed_by=$node->{needed_by};

# ---   *   ---   *   ---

    my @deps=values %$needs;
    my @chld=values %$needed_by;

    for my $c(@chld) {

      my $par=$c->{parent};

      if($par eq $root) {
        $node->pushlv($c);

      } elsif(grep {$par eq $ARG} @deps) {

        if($par ne $node->{parent}) {
          $par->pushlv($node);

        };

        $node->pushlv($c);

      };

    };

  };

};

# ---   *   ---   *   ---

sub list_by_priority($self) {

  my @pending=(@{$self->{leaves}});
  my $depth=0;

# ---   *   ---   *   ---
# walk the tree

  my $priority={};
  for my $node(@pending) {

    $self=shift @pending;
    if($self eq 1) {$depth++;next};
    if($self eq 0) {$depth--;next};

    # save depth of each node
    $priority->{$depth}//=[];
    push @{$priority->{$depth}},$node;
    unshift @pending,1,@{$self->{leaves}},0;

  };

# ---   *   ---   *   ---
# ^order nodes by depth

  my $result=[];
  my @order=sort {$a<=>$b} keys %$priority;

  for my $i(@order) {
    push @$result,@{$priority->{$i}};

  };

  $result=[map {$ARG->{value}} @$result];
  return $result;

};

# ---   *   ---   *   ---
1; # ret
