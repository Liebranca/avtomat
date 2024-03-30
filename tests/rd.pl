#!/usr/bin/perl
# ---   *   ---   *   ---

package main;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/avtomat/sys/';
  use Style;

  use rd;
  use ipret;

  use Bpack;

  use Arstd::Bytes;
  use Arstd::IO;

# ---   *   ---   *   ---
# the bit

use Fmat;
use Arstd::xd;

my $main = ipret(

  './lps/lps.rom',
  limit => 2

);

$main->prich(anima=>0);

# ---   *   ---   *   ---
1; # ret
