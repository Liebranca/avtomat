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

map {

  my @tab=$enc->exewrite_run();

  # dbout
  map {

    my $vref=$ARG->{vref};

    print sprintf "%02X:%02X ",
      $vref->{addr},$vref->{size};

    say join ',',map {
      $ARG->[1]

    } @{$vref->{req}};

  } @tab;

  say "_____________________\n";

} 1..$main->{passes}->{'solve'}+1;

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
