#!/usr/bin/perl
# ---   *   ---   *   ---
# STYLE
# KISS
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Style;
  use v5.42.0;
  use strict;
  use warnings;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    nop
    null
    no_match
    any_match

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.03.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub nop       {};
sub null      {return ''};
sub no_match  {return qr{\b\B}};
sub any_match {return qr{[^[:blank:]]+}};


# ---   *   ---   *   ---
1; # ret
