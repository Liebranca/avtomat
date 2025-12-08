#!/usr/bin/perl
# ---   *   ---   *   ---
# ~~

package install;
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

  @ARGV=grep {$_ ne 'clean'} @ARGV;
};


# ---   *   ---   *   ---
# deps

  use lib "$ENV{ARPATH}/lib/";
  use Avt;


# ---   *   ---   *   ---
# the bit

Avt::config {
  name => 'avtomat',
  bld  => 'ar:swan',
  xcpy => [qw()], # arperl olink rd symfind

  xprt => [qw(SWAN/*.c)],

  # the reason we're excluding so many things
  # is we more or less rewrote the core packages
  # and now need to build avtomat itself without
  # *also* rewriting all of this stuff
  scan => qr{(?:
    sys/A9M
  | sys/rd
  | sys/ipret
  | sys/xlate
  | sys/Tree/Exec
  | sys/Bitformat
  | sys/Bpack
  | sys/Icebox
  | sys/FStruc
  | sys/Ring
  | sys/id
  | sys/FF
  | sys/Mint
  | Avt/FFI
  | Avt/Droid
  | Avt/XS
  | Avt/olink
  | Avt/CRun
  | Avt/flatten
  | Emit/fasm
  | Emit/Cpp
  | Emit/html
  | Emit/Css
  | Emit/Python
  | Shb7/Bk/front
  | Shb7/Bk/jar
  | Type/Platypus
  | Type/cstr
  | scratch
  )}x,

  pre  => q[
    my $ex="$ENV{ARPATH}/avtomat/BOOTSTRAP";
    my $me=`$ex`;

    print $me;
    exit -1 if $me=~ m/^ARPATH missing/;
  ],
};


# ---   *   ---   *   ---
1; # ret
