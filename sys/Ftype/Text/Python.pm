#!/usr/bin/perl
# ---   *   ---   *   ---
# PYTHON
# Better known as walrus
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::Python;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use parent 'Ftype::Text';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v1.00.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# make ice

sub classattr {return {
  name => 'Python',
  ext  => '\.py$',
  hed  => '^#!.*python',
  mag  => 'Python script',

  type=>[qw(
    str int float list dict lambda
  )],

  resname=>[qw(
    False None True __$:name;>__
  )],

  intrinsic=>[qw(
    and as in is as with not or
  )],

  directive=>[qw(
    class def del assert async
    import from pass global nonlocal
  )],

  fctl=>[qw(
    await break continue
    if elif else except

    finally for raise return
    try while yield
  )],
}};


# ---   *   ---   *   ---
1; # ret
