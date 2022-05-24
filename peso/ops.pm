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
package peso::ops;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

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

use constant def=>{

  '->'=>[

    undef,
    undef,

    [-1,sub {my ($x,$y)=@_;return ($$x).'@'.($$y);}],

  ],

# ---   *   ---   *   ---

  '*^'=>[

    undef,
    undef,

    [0,sub {my ($x,$y)=@_;return ($$x)**($$y);}],

  ],'*'=>[

    undef,
    undef,

    [1,sub {my ($x,$y)=@_;return ($$x)*($$y);}],

  ],'/'=>[

    undef,
    undef,

    [2,sub {my ($x,$y)=@_;return ($$x)/($$y);}],

# ---   *   ---   *   ---

  ],'++'=>[

    [3,sub {my ($x)=@_;return ++$$x;}],
    [3,sub {my ($x)=@_;return $$x++;}],

    undef,

  ],'+'=>[

    undef,
    undef,

    [4,sub {my ($x,$y)=@_;return ($$x)+($$y);}],

# ---   *   ---   *   ---

  ],'--'=>[

    [5,sub {my ($x)=@_;return --$$x;}],
    [5,sub {my ($x)=@_;return $$x--;}],

    undef,

  ],'-'=>[

    undef,
    undef,

    [6,sub {my ($x,$y)=@_;return ($$x)-($$y);}],

# ---   *   ---   *   ---

  ],'?'=>[

    undef,
    [7,sub {my ($x)=@_;return ($$x)!=0;}],

    undef,

  ],'!'=>[

    undef,
    [8,sub {my ($x)=@_;return !($$x);}],

    undef,

  ],'~'=>[

    undef,
    [9,sub {my ($x)=@_;return ~($$x);}],

    undef,

# ---   *   ---   *   ---

  ],'<<'=>[

    undef,
    undef,

    [10,sub {my ($x,$y)=@_;return $$x<<$$y;}],

  ],'>>'=>[

    undef,
    undef,

    [11,sub {my ($x,$y)=@_;return $$x>>$$y;}],

# ---   *   ---   *   ---

  ],'|'=>[

    undef,
    undef,

    [12,sub {my ($x,$y)=@_;return $$x|$$y;}],

  ],'&'=>[

    undef,
    undef,

    [13,sub {my ($x,$y)=@_;return $$x& $$y;}],

  ],'^'=>[

    undef,
    undef,

    [14,sub {my ($x,$y)=@_;return $$x^ $$y;}],

# ---   *   ---   *   ---

  ],'<'=>[

    undef,
    undef,

    [15,sub {my ($x,$y)=@_;return $$x<$$y;}],

  ],'<='=>[

    undef,
    undef,

    [15,sub {my ($x,$y)=@_;return $$x<=$$y;}],

# ---   *   ---   *   ---

  ],'>'=>[

    undef,
    undef,

    [16,sub {my ($x,$y)=@_;return $$x>$$y;}],

  ],'>='=>[

    undef,
    undef,

    [16,sub {my ($x,$y)=@_;return $$x>=$$y;}],

# ---   *   ---   *   ---

  ],'||'=>[

    undef,
    undef,

    [17,sub {my ($x,$y)=@_;return $$x||$$y;}],

  ],'&&'=>[

    undef,
    undef,

    [18,sub {my ($x,$y)=@_;return $$x&& $$y;}],

# ---   *   ---   *   ---

  ],'=='=>[

    undef,
    undef,

    [19,sub {my ($x,$y)=@_;return $$x==$$y;}],

  ],'!='=>[

    undef,
    undef,

    [20,sub {my ($x,$y)=@_;return $$x!=$$y;}],

  ],

};

# ---   *   ---   *   ---
1; # ret
