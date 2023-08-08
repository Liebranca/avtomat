#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH MACRO META
# Ops to output code
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::Macro::Meta;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use List::Util qw(min max);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Bytes;
  use Arstd::Int;

  use Mach::Seg;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $INS=>[qw(

    strtest

  )];

# ---   *   ---   *   ---
# attempts string manipulation

sub strtest($reg) {

  say $reg->ptr_deref();

};

# ---   *   ---   *   ---
1; # ret
