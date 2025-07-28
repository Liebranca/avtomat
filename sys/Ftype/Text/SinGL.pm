#!/usr/bin/perl
# ---   *   ---   *   ---
# SINGL
# Headermaker
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::SinGL;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{'ARPATH'}/lib/sys/";
  use Arstd::Re qw(re_eaf);
  use Ftype::Text;


# ---   *   ---   *   ---
# make ice

BEGIN { Ftype::Text->new(

  name => 'SinGL',

  ext  => '\.(sg|glsl)$',
  mag  => '^SIN_SHADER',
  com  => '//',
  lcom => '//',


  type=>[qw(
    void bool int uint float

    [biu]?vec[234]
    mat[234]

    sampler([^\s]+)?
    buffer

  )],

  specifier=>[qw(
    const uniform in out flat

  )],


  intrinsic=>[qw()],

  directive=>[qw(
    struct union layout

  )],

  fctl=>[qw(
    if else for while do
    switch case default
    break continue return

  )],

  resname=>[qw()],
  preproc=>re_eaf('#',lbeg=>0,opscape=>1),


)};


# ---   *   ---   *   ---
1; # ret
