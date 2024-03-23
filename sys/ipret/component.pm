#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET:COMPONENT
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

package ipret::component;

  use v5.36.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,$ipret) {
  return bless {ipret=>$ipret},$class;

};

# ---   *   ---   *   ---
# get ref to ISA spec

sub ISA($self) {

  my $main = $self->{ipret};
  my $mc   = $main->{mc};

  return $mc->{ISA};

};

# ---   *   ---   *   ---
1; # ret
