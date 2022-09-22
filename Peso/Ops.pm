#!/usr/bin/perl
# ---   *   ---   *   ---
# OPS
# Operators and what they do
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Peso::Ops;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

# ---   *   ---   *   ---

  our $VERSION=v1.00.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# format is as follows:
#
#   sequence=>[
#     when  x*: [priority, sub],
#     when  *x: [priority, sub],
#     when x*y: [priority, sub],
#
#   ]
#
#: undef means not used with that
#  order or number of operands

# ---   *   ---   *   ---

Readonly our $TABLE=>{

  q{->}=>[

    undef,
    undef,

    [-1,sub($x,$y) {return ($$x).q{@}.($$y)}],

# ---   *   ---   *   ---

  ],q{*^}=>[

    undef,
    undef,

    [0,sub($x,$y) {return ($$x)**($$y)}],

  ],q{*}=>[

    undef,
    undef,

    [1,sub($x,$y) {return ($$x)*($$y)}],

  ],q{%}=>[

    undef,
    undef,

    [2,sub($x,$y) {return ($$x)%($$y)}],

  ],q{/}=>[

    undef,
    undef,

    [2,sub($x,$y) {return ($$x)/($$y)}],

  ],q{++}=>[

    [3,sub($x) {return $$x++}],
    [3,sub($x) {return ++$$x}],

    undef,

  ],q{+}=>[

    undef,
    undef,

    [4,sub($x,$y) {return ($$x)+($$y)}],

# ---   *   ---   *   ---

  ],q{--}=>[

    [5,sub($x) {return $$x--}],
    [5,sub($x) {return --$$x}],

    undef,

  ],q{-}=>[

    undef,
    undef,

    [6,sub($x,$y) {return ($$x)-($$y)}],

# ---   *   ---   *   ---

  ],q{?}=>[

    undef,
    [7,sub($x) {return ($$x)!=0}],

    undef,

  ],q{!}=>[

    undef,
    [8,sub($x) {return !($$x)}],

    undef,

  ],q{~}=>[

    undef,
    [9,sub($x) {return ~($$x)}],

    undef,

# ---   *   ---   *   ---

  ],q{<<}=>[

    undef,
    undef,

    [10,sub($x,$y) {return $$x<<$$y}],

  ],q{>>}=>[

    undef,
    undef,

    [11,sub($x,$y) {return $$x>>$$y}],

# ---   *   ---   *   ---

  ],q{|}=>[

    undef,
    undef,

    [12,sub($x,$y) {return $$x|$$y}],

  ],q{&}=>[

    undef,
    undef,

    [13,sub($x,$y) {return $$x& $$y}],

  ],q{^}=>[

    undef,
    undef,

    [14,sub($x,$y) {return $$x^ $$y}],

# ---   *   ---   *   ---

  ],q{<}=>[

    undef,
    undef,

    [15,sub($x,$y) {return $$x<$$y}],

  ],q{<=}=>[

    undef,
    undef,

    [15,sub($x,$y) {return $$x<=$$y}],

# ---   *   ---   *   ---

  ],q{>}=>[

    undef,
    undef,

    [16,sub($x,$y) {return $$x>$$y}],

  ],q{>=}=>[

    undef,
    undef,

    [16,sub($x,$y) {return $$x>=$$y}],

# ---   *   ---   *   ---

  ],q{||}=>[

    undef,
    undef,

    [17,sub($x,$y) {return $$x||$$y}],

  ],q{&&}=>[

    undef,
    undef,

    [18,sub($x,$y) {return $$x&& $$y}],

# ---   *   ---   *   ---

  ],q{==}=>[

    undef,
    undef,

    [19,sub($x,$y) {return $$x eq $$y}],

  ],q{!=}=>[

    undef,
    undef,

    [20,sub($x,$y) {return $$x ne $$y}],

  ],q{,}=>[

    undef,
    undef,

    [99,sub($x,$y) {return "$$x,$$y"}],

  ],

};

# ---   *   ---   *   ---
1; # ret
