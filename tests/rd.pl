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
  use xlate;

  use Fmat;
  use Arstd::xd;

# ---   *   ---   *   ---
# run and dbout

my $xlate = xlate->new('./lps/test.pe',limit=>2);
my $main  = $xlate->run();

# ---   *   ---   *   ---
1; # ret
