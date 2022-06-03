#!/usr/bin/perl
# ---   *   ---   *   ---
# sadface

# ---   *   ---   *   ---

# deps
package langdefs::js;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---

lang::def::nit(

  -NAME =>'js',
  -EXT  =>'\.js$',
  -HED  =>'#!.*node',

  -MAG  =>'JavaScript script',

  -COM  =>'//',

# ---   *   ---   *   ---

  -TYPES=>[qw(
    function class var let const

  )],

  -SPECIFIERS=>[qw(
    async await export

  )],

# ---   *   ---   *   ---

  -INTRINSICS=>[qw(
    extends typeof void
    new delete in with

  )],

  -DIRECTIVES=>[qw(
    import

  )],

# ---   *   ---   *   ---


  -FCTLS=>[qw(

    each of yield finally

    if else for while do switch
    case default try throw catch
    break continue return

  )],

  -RESNAMES=>[qw(
    true false null undefined this

  )],

);

# ---   *   ---   *   ---
1; # ret
