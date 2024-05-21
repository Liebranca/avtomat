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
  use Mint qw(image mount);

  use Fmat;
  use Arstd::xd;

# ---   *   ---   *   ---
# parse, solve and assemble,
# then freeze

sub make($src,$out='a.out'){

  my $main=ipret($src,limit=>2);
  my $path=image $out=>$main;

  return $path;

};

# ---   *   ---   *   ---
# ^retrieve

sub load($src) {mount $src};

# ---   *   ---   *   ---
# run and dbout

my $main=load make './lps/test.pe';

$main->{stage}--;
$main->{pass}=0;

$main->assemble();

$main->run();
$main->prich(

  anima => 1,
  stack => 0,

  mem   => 'outer',
  tree  => 0,

);

# ---   *   ---   *   ---
1; # ret
