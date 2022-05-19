#!/usr/bin/perl
# ---   *   ---   *   ---
# DECLS
# Names and patterns for LyPerl
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package lyperl::decls;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/avtomat/';
  use pluts;

# ---   *   ---   *   ---

my $CLASS;if(!defined $CLASS) {

  my $ATTRS={

  -NAMES=>[
    q('((\$?[\$|\@|\%])?([_\w][_\w\d]*))'),
    0,pluts::ATTR_GET

  ],

# ---   *   ---   *   ---

  };$CLASS=pluts::DEFAULTS($ATTRS);

my $i=1;
for my $line(split "\n",$CLASS) {
  print $i++." $line\n";

};

  eval($CLASS);

};

# ---   *   ---   *   ---
1; # ret
