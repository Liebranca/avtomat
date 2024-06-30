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

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# type switch

sub argproc($self,$vref,%O) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $eng  = $main->{engine};


  # have symbol?
  if($vref->{type} eq 'sym') {
    return $eng->symfet($vref->{name});

  # have tree!
  } else {
    return $eng->value_solve($vref->{name},%O);

  };

};

# ---   *   ---   *   ---
1; # ret
