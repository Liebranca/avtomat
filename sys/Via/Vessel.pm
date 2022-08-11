#!/usr/bin/perl
# ---   *   ---   *   ---
# VIA SHIP
# Because 'message' is
# such a boring term
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Via::Ship;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use parent 'Via';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# NOTE: just doodling about
#
# $ sys
# @ net
# % csm
# ~ sin
# ^ mny

# ---   *   ---   *   ---
# destructor

sub DESTROY($self) {

  my $idex=$self->{idex};
  my $frame=$self->{frame};

  # give back slot
  $frame->{vessels}->[$idex]->take($idex);

  # announce sinking of vessel
  say {*STDERR} "$self->{name} sunk";

};

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,$src) {

  my $self=Via::nit($class,$frame,$name);

  $self->{src}=$src;
  $self->{idex}=$frame->{ships}->give($self);

  $self->{name}=

    $src->{name}.

    '>>:vessel_'.
    $self->{idex}

  ;

  $self->{load}=[];
  return $self;

};

# ---   *   ---   *   ---

sub sail($self) {};

# ---   *   ---   *   ---
1; # ret
