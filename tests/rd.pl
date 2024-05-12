#!/usr/bin/perl
# ---   *   ---   *   ---

package main;

  use v5.36.0;
  use strict;
  use warnings;

  use Storable;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/avtomat/sys/';
  use Style;

  use ipret;
  use Vault;

  use Fmat;
  use Arstd::xd;

# ---   *   ---   *   ---
# parse, solve and assemble,
# then freeze

sub make($src,$out='a.out'){

  my $main=ipret($src,limit=>2);

  $main->to_obj();

#  Vault::image $out => $main;

  return $main;

};

# ---   *   ---   *   ---
# ^retrieve

sub load($src) {Vault::mount $src};

# ---   *   ---   *   ---
# run and dbout

my $main=make './lps/test.pe';

$main->run();
$main->prich(

  anima => 1,
  stack => 0,

  mem   => 'outer',
  tree  => 0,

);

# ---   *   ---   *   ---
1; # ret
