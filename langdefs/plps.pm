#!/usr/bin/perl
# peso language pattern syntax

# ---   *   ---   *   ---
# deps
package langdefs::plps;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---

use constant plps_ops=>{

  '?'=>[

    [0,sub {my ($x)=@_;$x->{optional}=1;}],
    undef,
    undef,

  ],'+'=>[

    [1,sub {my ($x)=@_;$x->{consume_equal}=1;}],

    undef,
    undef,

  ],'--'=>[

    [2,sub {my ($x)=@_;$x->{rewind}=1;}],

    undef,
    undef,

  ],

};

# ---   *   ---   *   ---

BEGIN {
lang::def::nit(

  -NAME=>'plps',

  -EXT=>'\.pe\.lps',
  -HED=>'\$:%plps;>',
  -MAG=>'Peso-style language patterns',

# ---   *   ---   *   ---

  -TYPES=>[qw(

    type spec dir itri

    sbl ptr ode cde
    sep del ari

    fctl sbl_decl ptr_decl pattern

  )],

  -DIRECTIVES=>[qw(
    beg end

  )],

# ---   *   ---   *   ---

  -ODE=>'[<]',
  -CDE=>'[>]',

  -DEL_OPS=>'[<>]',
  -NDEL_OPS=>'[?+-]',
  -OP_PREC=>plps_ops,

);

};

# ---   *   ---   *   ---
1; # ret
