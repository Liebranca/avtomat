#!/usr/bin/perl
# ---   *   ---   *   ---
# BOOTSTRAP

BEGIN {

  my $clean=shift @ARGV;

  my $ex=$ENV{'ARPATH'}.'/avtomat/AR.pl';
  if($clean eq 'clean') {
    $ex.=q{ }.'clean';

  } elsif(defined $clean && length $clean) {
    unshift @ARGV,$clean;

  };

  my $me=`$ex`;

  print $me;
  if($me=~ m/^ARPATH missing/) {
    exit -1;

  };

};


# ---   *   ---   *   ---
# deps

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Shb7;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Avt;


# ---   *   ---   *   ---
# the bit

Avt::config {

  name => 'avtomat',
  xcpy => [qw(arperl olink rd symfind)],

  pre  => q[
    my $ex="$ENV{ARPATH}/avtomat/AR.pl";
    my $me=`$ex`;

    print $me;
    exit if $me=~ m/^ARPATH missing/;

  ],

};


# ---   *   ---   *   ---
1; # ret
