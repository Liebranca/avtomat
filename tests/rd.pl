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

  use rd;
  use ipret;
  use A9M;

  use Bpack;

  use Arstd::Bytes;
  use Arstd::Path;
  use Arstd::IO;

  use Fmat;
  use Arstd::xd;

# ---   *   ---   *   ---
# parse, solve and assemble

my $main=ipret(

  './lps/test.pe',
  limit => 2,

);

## ---   *   ---   *   ---
# freeze!
#
#use Vault;
#Vault::image 'a.out'
#  => $main;
#
#$main=Vault::mount 'a.out';
#
# ---   *   ---   *   ---
# run and dbout

$main->run();
$main->prich(

  anima => 1,
  stack => 0,

  mem   => 'outer',
  tree  => 0,

);

# ---   *   ---   *   ---
1; # ret
