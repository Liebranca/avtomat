#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M COMPONENT
# Template for pieces
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::component;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get host machine

sub getmc($self) {

  my $class = $self->{mccls};
  my $mc    = $class->ice($self->{mcid});

  return $mc;

};

# ---   *   ---   *   ---
# add universal flags to object

sub set_uattrs($self,@keys) {

  my $mc    = $self->getmc();
  my $flags = $mc->{bk}->{flags};

  $flags->defnit($self,@keys);


  return;

};

# ---   *   ---   *   ---
1; # ret
