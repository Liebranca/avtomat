#!/usr/bin/perl
# ---   *   ---   *   ---
# CSS
# ~
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::CSS;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use parent "Ftype::Text";


# ---   *   ---   *   ---
# info

  our $VERSION = "v0.00.1a";
  our $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# make ice

sub classattr {return {
  name  => "CSS",
  ext   => q[\.css$],
  com   => "/*|*/",
}};


# ---   *   ---   *   ---
# syntax definitions for strtok

sub strtok_syx {
  return [
    # comments
    Arstd::seq::com()->{cmulti},

    # strings
    Arstd::seq::str()->{squote},
    Arstd::seq::str()->{dquote},

    # hide scopes
    Arstd::seq::delim()->{curly},

    # preprocessor
    Arstd::seq::pproc()->{c},
  ];
};


# ---   *   ---   *   ---
1; # ret
