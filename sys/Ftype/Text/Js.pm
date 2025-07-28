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
  use Ftype::Text;


# ---   *   ---   *   ---
# make ice

BEGIN { Ftype::Text->new(

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

)};


# ---   *   ---   *   ---
1; # ret
