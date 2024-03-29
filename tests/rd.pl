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
  use Bpack;

  use Arstd::Bytes;
  use Arstd::IO;

# ---   *   ---   *   ---
# the bit

use Fmat;
use Arstd::xd;

my $main = rd('./lps/lps.rom');
$main->prich();

# ---   *   ---   *   ---
1; # ret
