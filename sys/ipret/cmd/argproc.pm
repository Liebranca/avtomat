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
  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# symbol lookup

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
# type switch

sub argproc($self,$vref) {

  my $main = $self->{frame}->{main};
  my $eng  = $main->{engine};

  if($vref->{type} eq 'sym') {
    return $self->symfet($vref);

  } else {
    return $eng->value_solve($vref->{id});

  };

};

# ---   *   ---   *   ---
1; # ret
