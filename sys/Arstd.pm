#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD
# Protos used often
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    $O_RD
    $O_WR
    $O_EX

    $O_FILE
    $O_STR

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.03.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $O_RD  =>0x0004;
  Readonly our $O_WR  =>0x0002;
  Readonly our $O_EX  =>0x0001;

  # just so we don't have to
  # -e(name) && -f(name) every single time
  Readonly our $O_FILE=>0x0008;
  Readonly our $O_STR =>0x0010;

# ---   *   ---   *   ---
1; # ret
