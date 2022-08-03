#!/usr/bin/perl
# ---   *   ---   *   ---
# python defs

# ---   *   ---   *   ---

# deps
package Lang::Python;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use parent 'Lang::Def';

# ---   *   ---   *   ---

Lang::Python->nit(

  name=>'Python',
  ext=>'\.py$',
  hed=>'^#!.*python',

  mag=>'Python script',

# ---   *   ---   *   ---

  types=>[qw(
    str int float list dict lambda

  )],

  resnames=>[qw(
    False None True __$:names;>__

  )],

# ---   *   ---   *   ---

  intrinsics=>[qw(
    and as in is as with not or

  )],

  directives=>[qw(
    class def del assert async
    import from pass global nonlocal

  )],

# ---   *   ---   *   ---

  fctls=>[qw(

    await break continue
    if elif else except

    finally for raise return
    try while yield

  )],

);

# ---   *   ---   *   ---
1; # ret
