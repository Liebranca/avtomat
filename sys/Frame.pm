#!/usr/bin/perl
# ---   *   ---   *   ---
# FRAME
# Instance containers
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Frame;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# invokes class constructor

sub nit($frame,@args) {
  return $frame->{class}->nit(
    $frame,@args

  );

};

# ---   *   ---   *   ---
# builds a new container

sub new(%O) {

  my $frame=bless \%O;
  return $frame;

};

# ---   *   ---   *   ---
1; # ret
