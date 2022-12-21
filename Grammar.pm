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
# ROM

  our $OR={
    name=>q[|]

  };

  sub Frame_Vars($class) { return {

    -ns   => [],
    -cns  => [],

  }};

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
# decon string using rules

sub parse($class,$prog) {

  my $self=bless {
    frame => $class->new_frame(),

  },$class;

  my $gram=$class->get_top();
  my $tree=$gram->parse($self,$prog);

  return $tree;

};

# ---   *   ---   *   ---
# generates branches from descriptor array

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
# add object to specific namespace

sub ns_decl($self,$o,@path) {

  my $ns  = $self->{frame}->{ns};

  my $hns = {@$ns};
  my $dst = \$hns;

  for my $key(@path) {

    $dst=\( (${$dst})->{$key} );

  };

  $$dst=$o;

};

# ---   *   ---   *   ---
1; # ret
