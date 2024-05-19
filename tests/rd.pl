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

  my $main=rd($src,limit=>2);
  my $prep=$main->{preproc};

  fatdump \$prep->{tab},blessed=>1;

  my $path=image 'a.out'=>$prep;
     $prep=mount $path;


  fatdump \$prep->{tab},blessed=>1;

  exit;

#  return $main->to_obj($out);

};

# ---   *   ---   *   ---
# ^retrieve

sub load($src) {mount $src};

# ---   *   ---   *   ---
# run and dbout

my $main=load make './lps/test.pe';

#$main->run();
#$main->prich(
#
#  anima => 1,
#  stack => 0,
#
#  mem   => 'outer',
#  tree  => 0,
#
#);

# ---   *   ---   *   ---
1; # ret
