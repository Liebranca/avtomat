#!/usr/bin/perl
# ---   *   ---   *   ---
# GENERIC
# Refuses to elaborate
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::cmdlib::generic;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'ipret::cmd';
  BEGIN {ipret::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# solves dbout values

cmdsub echo => q() => q{


  # get ctx
  my $main  = $self->{frame}->{main};
  my $eng   = $main->{engine};


  # can solve values?
  my @solved=$eng->argtake(map {
    $ARG->{id}

  } @{$branch->{vref}});

  return $branch if ! @solved;


  # all solved, no need to repeat ;>
  $branch->{vref}=\@solved;

  return;

};

# ---   *   ---   *   ---
# hammer time!

cmdsub stop => q() => q{};

# ---   *   ---   *   ---
1; # ret
