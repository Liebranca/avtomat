#!/usr/bin/perl
# ---   *   ---   *   ---
# SWITCH
# Turn me off
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::cmdlib::switch;

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
# ~

cmdsub 'switch' => q() => q{


  my $main = $self->{frame}->{main};
  my $eng  = $main->{engine};

  my @args=@{$branch->{vref}};
  my $iter=(is_arrayref $args[-1])
    ? pop @args
    : 0
    ;


  if($iter) {

  } else {

  };


  return;

};

# ---   *   ---   *   ---
# ^icef*ck

w_cmdsub 'switch' => q() => qw(
  on or

);

cmdsub 'off' => q() => q{};

# ---   *   ---   *   ---
1; # ret
