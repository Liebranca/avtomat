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

  use Fmat;
  use Arstd::xd;

# ---   *   ---   *   ---
# parse and solve

my $main = ipret(

  './lps/test.rom',
  limit => 2

);

# ---   *   ---   *   ---
# ^assemble!

my $enc=$main->{encoder};
$enc->exewrite_run();

# ---   *   ---   *   ---
# manually set entry ;>

my $mc    = $main->{mc};
my $anima = $mc->{anima};
my $rip   = $anima->fetch($anima->exec_ptr);
my $seg   = $mc->ssearch('non','code');

$rip->store(
  $mc->segid($seg),
  deref=>0

);

# ---   *   ---   *   ---
# run and dbout

$main->{engine}->exe();
$main->prich(anima=>1,mem=>'outer',tree=>0);

# ---   *   ---   *   ---
1; # ret
