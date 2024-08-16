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

Avt::set_config(

  name      => 'avtomat',
  xcpy      => [qw(arperl olink rd symfind)],

  pre_build => q(

    my $ex=$ENV{'ARPATH'}.'/avtomat/AR.pl';
    my $me=`$ex`;

    print $me;
    if($me=~ m/^ARPATH missing/) {
      exit;

    };

  ),

);

# ---   *   ---   *   ---

Avt::scan();
Avt::config();
Avt::make();

# ---   *   ---   *   ---
1; # ret
