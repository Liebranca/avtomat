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

  use Fmat;
  use Arstd::xd;

# ---   *   ---   *   ---
# run and dbout

my $main=ipret('./lps/test.pe',limit=>2);

$main->run();
$main->prich(

  anima => 1,
  stack => 0,

  mem   => 'outer',
  tree  => 0,

);

# ---   *   ---   *   ---
1; # ret
