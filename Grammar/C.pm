#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO GRAMMAR
# Recursive swan song
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::C;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Array;
  use Arstd::IO;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/avtomat/hacks/';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use Lang;
  use parent 'Grammar';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $REGEX=>{

    term  => Lang::nonscap(q[;]),
    nterm => Lang::nonscap(

      q[;],

      iv     => 1,
      mod    => '+',
      sigws  => 1,

    ),

  };

# ---   *   ---   *   ---

  Readonly our $NTERM=>{
    name => $REGEX->{nterm},
    fn   => 'capt',

  };

  Readonly our $TERM=>{
    name => $REGEX->{term},
    fn   => 'term',

  };

# ---   *   ---   *   ---

  Readonly our $ANY=>{
    name => 'any',
    fn   => 'clip',

    chld => [
      $NTERM

    ],

  };

  Readonly our $EXPR=>{

    name => 'expr',
    chld => [
      $ANY,
      $TERM,

    ],

  };

# ---   *   ---   *   ---
# GBL

  Grammar::C->mkrules($EXPR);

# ---   *   ---   *   ---
# test

  my $prog = q[hello;];
  my $ice  = Grammar::C->parse($prog);

  $ice->{tree}->prich();

# ---   *   ---   *   ---
1; # ret
