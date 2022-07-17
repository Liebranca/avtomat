#!/usr/bin/perl
# ---   *   ---   *   ---
# python defs

# ---   *   ---   *   ---

# deps
package langdefs::python;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---

lang::def::nit(

  name=>'python',
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

  instrinsics=>[qw(
    and as in is as with not or

  )],

  directives=>[qw(
    class def del assert async
    import from pass global nonlocal

  )],

# ---   *   ---   *   ---

  ftcls=>[qw(

    await break continue
    if elif else except

    finally for raise return
    try while yield

  )],

);

# ---   *   ---   *   ---
1; # ret
