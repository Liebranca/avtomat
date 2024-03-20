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

my $rd = rd('./lps/lps.rom');
my $mc = $rd->{mc};

my $l2  = ref $rd->{l2};
my $rev = "$l2\::branch_solve";

$rd->walk(limit=>2,rev=>\&$rev);

$mc->{anima}->prich();
$rd->prich();

# ---   *   ---   *   ---
1; # ret
