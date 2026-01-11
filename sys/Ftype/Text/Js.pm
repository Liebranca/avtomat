#!/usr/bin/perl
# ---   *   ---   *   ---
# JAVASCRIPT
# It's OK
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::Js;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use parent 'Ftype::Text';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v1.00.2';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# make ice

sub classattr {return {
  name  => 'Js',
  ext   => '\.js$',
  hed   => '#!.*node',

  mag   => 'JavaScript script',
  com   => '//',
  lcom  => '//',

  specifier=>[qw(
    async await export
  )],

  intrinsic=>[qw(
    extends typeof void
    new delete in with
  )],

  directive=>[qw(
    import function class
  )],

  fctl=>[qw(
    each of yield finally

    if else for while do switch
    case default try throw catch
    break continue return
  )],

  resname=>[qw(
    true false null undefined this
    var let const
  )],
}};


# ---   *   ---   *   ---
# syntax definitions for strtok

sub strtok_syx {
  return [
    # comments
    Arstd::seq::com()->{cline},
    Arstd::seq::com()->{cmulti},

    # strings
    Arstd::seq::str()->{squote},
    Arstd::seq::str()->{dquote},

    # we add in this bit to ensure that
    # template literals can be tokenized
    # whenever there's a `${...}` placeholder
    # within them, as those expressions can
    # contain a nested literal
    {
      %{Arstd::seq::str()->{backtick}},
      inner=>[Arstd::seq::delim()->{curly}],
    },

    # vanilla Javascript doesn't have a
    # preprocessor (to my knowledge), but
    # i already have it implemented, so why not?
    Arstd::seq::pproc()->{c},
  ];
};


# ---   *   ---   *   ---
1; # ret
