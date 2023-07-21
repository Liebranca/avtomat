#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD INT
# Common numerical problems
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::Int;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys';
  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(int_urdiv);

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.3;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

# ---   *   ---   *   ---
# cstruc

sub nit($class,$value) {
  return bless \$value,$class;

};

# ---   *   ---   *   ---
# divide and round up

sub urdiv($a,$b) {
  return int(($a/$b)+0.9999);

};

# ---   *   ---   *   ---
# exporter names

  *int_urdiv=*urdiv;

# ---   *   ---   *   ---
1; # ret
