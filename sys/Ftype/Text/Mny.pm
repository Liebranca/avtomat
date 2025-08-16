#!/usr/bin/perl
# ---   *   ---   *   ---
# MONEY
# It makes me lazy
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::Mny;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Ftype::Text;


# ---   *   ---   *   ---
# make ice

BEGIN { Ftype::Text->new(
  name => 'Mny',
  ext  => '\.mny$',
  hed  => '\$mny;',
  mag  => '\$:get0x24;>',

  highlight=>[
    qr{f:([^[:blank:]]+/[^[:blank:]]+)+} => 0x04,
    qr{[/:.]}   => 0x0F,
    qr{^>+.+$}  => 0x83,
    qr{^\*>.+$} => 0x8E,
    qr{^~}      => 0x01,
    qr{^x}      => 0x02,

  ],

)};


# ---   *   ---   *   ---
1; # ret
