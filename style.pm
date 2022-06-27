#!/usr/bin/perl
# ---   *   ---   *   ---
# STYLE
# Boilerpaste for constants
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package style;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    MEMPTR
    MEMPTR_SZBYTE
    MEMPTR_SZMASK

    NULL
    NULLSTR

    WARNING
    ERROR
    FATAL

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# constants

use constant {

  WARNING=>"\e[33;22m",
  ERROR=>"\e[35;1m",
  FATAL=>"\e[31;1m",

  MEMPTR=>0xFFB10C<<40,

  MEMPTR_SZBYTE=>0xFF<<32,
  MEMPTR_SZMASK=>0x08<<32,

};use constant {
  NULL=>MEMPTR|MEMPTR_SZMASK|0xDEADBEEF,
  NULLSTR=>q(),

};

# ---   *   ---   *   ---
1; # ret
