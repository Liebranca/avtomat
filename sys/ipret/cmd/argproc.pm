#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET:CMD ARGPROC
# VREF mambo
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::cmd::argproc;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ~

sub symfet($self,$vref) {

  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};

  # can find symbol?
  my $name = $l1->is_sym($vref->{id});
  my $sym  = $mc->ssearch($name);

  return $sym;

};

# ---   *   ---   *   ---
1; # ret
