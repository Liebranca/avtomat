#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT
# Base class for code emitters
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Emit;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# transforms type to peso equivalent

sub typetrim($class,$typeref) {

  $$typeref=~ s[^\s*|\s*$][]sg;

};

sub typecon($class,$type) {

  my $tab=$class->get_typetab();
  $class->typetrim(\$type);

  if(exists $tab->{$type}) {
    $type=$tab->{$type};

  };

  return $type;

};

# ---   *   ---   *   ---
1; # ret
