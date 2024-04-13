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
  use A9M;

  use Bpack;

  use Arstd::Bytes;
  use Arstd::IO;

  use Fmat;
  use Arstd::xd;

# ---   *   ---   *   ---
# parse, solve and assemble

my $main=rd(

  './lps/test.rom',
  limit => 2

);

#$main->assemble();

## ---   *   ---   *   ---
# run and dbout

#$main->run();
$main->prich(

  anima => 0,
  stack => 0,

  mem   => '',
  tree  => 1,

);

# ---   *   ---   *   ---
1; # ret
