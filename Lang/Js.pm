#!/usr/bin/perl
# ---   *   ---   *   ---
# sadface

# ---   *   ---   *   ---

# deps
package Lang::Js;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use parent 'Lang::Def';

# ---   *   ---   *   ---

BEGIN {
Lang::Js->nit(

  name=>'Js',
  ext=>'\.js$',
  hed=>'#!.*node',

  mag=>'JavaScript script',

  com=>'//',

# ---   *   ---   *   ---

  specifiers=>[qw(
    async await export

  )],

# ---   *   ---   *   ---

  intrinsics=>[qw(
    extends typeof void
    new delete in with

  )],

  directives=>[qw(
    import function class var let const

  )],

# ---   *   ---   *   ---


  ftcls=>[qw(

    each of yield finally

    if else for while do switch
    case default try throw catch
    break continue return

  )],

  resnames=>[qw(
    true false null undefined this

  )],

);
};

# ---   *   ---   *   ---
1; # ret
