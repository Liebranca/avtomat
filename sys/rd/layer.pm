#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LAYER
# Common and annoying methods
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::layer;

  use v5.36.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

  use Chk;
  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {main=>undef},

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$main) {

  # get attrs
  my $O={};
  $class->defnit($O);

  # ^make ice and give
  $O->{main}=$main;
  return bless $O,$class;

};

# ---   *   ---   *   ---
# get ref to ISA spec

sub ISA($self) {

  my $main = $self->{main};
  my $mc   = $main->{mc};

  return $mc->{ISA};

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {
  return main=>$self->{main};

};

# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {

  my $self=(! is_blessref $O)
    ? bless $O,$class
    : $O
    ;

  return $self;

};

# ---   *   ---   *   ---
1; # ret
