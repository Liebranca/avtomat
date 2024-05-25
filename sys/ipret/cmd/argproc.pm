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

sub symfet($self,$vref,%O) {

  # defaults
  $O{sym_asis} //= 0;

  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};


  # can find symbol?
  my $have = (Tree->is_valid($vref->{id}))
    ? $vref->{id}->{value}
    : $vref->{id}
    ;

  my $name=$l1->untag($have)->{spec};

  my $sym=(! $O{sym_asis})
    ? $mc->ssearch(split $mc->{pathsep},$name)
    : $name
    ;

  return $sym;

};

# ---   *   ---   *   ---
# type switch

sub argproc($self,$vref,%O) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $eng  = $main->{engine};


  # have symbol?
  if($vref->{type} eq 'sym') {
    return $self->symfet($vref,%O);

  # have tree!
  } else {
    return $eng->value_solve($vref->{id},%O);

  };

};

# ---   *   ---   *   ---
1; # ret
