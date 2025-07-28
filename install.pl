#!/usr/bin/perl
# ---   *   ---   *   ---
# ~~

package mkavto;
  use v5.42.0;
  use strict;
  use warnings;


# ---   *   ---   *   ---
# run BOOTSTRAP

BEGIN {
  my $clean  = int grep {$_ eq 'clean'} @ARGV;
  my $ex     = "$ENV{ARPATH}/avtomat/BOOTSTRAP";
     $ex    .= ' clean' if $clean;

  my $me=`$ex`;

  print $me;
  exit  -1 if $me=~ m/^ARPATH missing/;

  @ARGV=grep {$_ eq 'clean'} @ARGV;

};


# ---   *   ---   *   ---
# deps

  use lib "$ENV{ARPATH}/lib/sys/";
  use Shb7;

  use lib "$ENV{ARPATH}/lib/";
  use Avt;


# ---   *   ---   *   ---
# the bit

Avt::config {
  name => 'avtomat',
  xcpy => [qw(arperl olink rd symfind)],

  pre  => q[
    my $ex="$ENV{ARPATH}/avtomat/BOOTSTRAP";
    my $me=`$ex`;

    print $me;
    exit -1 if $me=~ m/^ARPATH missing/;

  ],

};


# ---   *   ---   *   ---
1; # ret
