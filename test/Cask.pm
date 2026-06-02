#!/usr/bin/perl

package tests::Cask;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Cask;
  use Arstd::fatdump;


# ---   *   ---   *   ---
# ~~

my $cask=Cask->new('$$','$%');
$cask->give(0);
$cask->take('!$');
fatdump \$cask,blessed=>1;


# ---   *   ---   *   ---
1; # ret
