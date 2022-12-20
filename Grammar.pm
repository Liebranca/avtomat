#!/usr/bin/perl
# ---   *   ---   *   ---
# GRAMMAR
# Base class for all
# lps-derived parsers
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;
  use Tree::Grammar;

  use parent 'St';

# ---   *   ---   *   ---
# global state

  our $Top;

# ---   *   ---   *   ---
# returns our $Top for calling package

sub get_top($class) {

  no strict 'refs';
  return ${"$class\::Top"};

};

sub set_top($class,$name) {

  no strict 'refs';

  my $f=Tree::Grammar->get_frame();
  ${"$class\::Top"}=$f->nit(value=>$name);

  return ${"$class\::Top"};

};

# ---   *   ---   *   ---
# new instance

sub parse($class,$prog) {

  state @n_frames=reverse (0..63);

  my $id=pop @n_frames;

  my $self=bless {

    id    => $id,
    frame => $class->get_frame($id),

  },$class;

  my $gram=$class->get_top();
  my $tree=$gram->parse($prog);

  push @n_frames,$id;

  return $tree;

};

# ---   *   ---   *   ---
# generates branch

sub mkrules($class,@rules) {

  # shorten subclass name
  my $name    = $class;
  $name       =~ s[^Grammar\::][];

  # build root
  my $top     = $class->set_top($name);
  my @anchors = ($top);

  # walk
  while(@rules) {

    my $value=shift @rules;

    # go back one step in hierarchy
    if($value eq 0) {
      pop @anchors;
      next;

    };

    # get parent node
    my $anchor=$anchors[-1];

    # instantiate
    my $nd=$anchor->init(

      $value->{name},

      dom => $value->{dom},
      fn  => $value->{fn},

      opt => $value->{opt},

    );

    # recurse
    if($value->{chld}) {

      unshift @rules,@{$value->{chld}},0;
      push    @anchors,$nd;

    };

  };

};

# ---   *   ---   *   ---
1; # ret
