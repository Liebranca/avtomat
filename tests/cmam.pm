#!/usr/bin/perl
# ---   *   ---   *   ---

package tests::proc;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/";
  use lib "$ENV{ARPATH}/lib/sys";
  use Chk qw(is_file);
  use MAM;

# ---   *   ---   *   ---
# ~~

sub run {
  my @file=grep {is_file $ARG} @ARGV;
  $ENV{MAMROOT}=$ENV{ARPATH};
  for(@file) {
    my $mam=MAM->new();
    $mam->set_module('avtomat');
    $mam->set_rap(1);

    say $mam->run($ARG);

  };

  return;

};

run;

# ---   *   ---   *   ---
1; # ret
