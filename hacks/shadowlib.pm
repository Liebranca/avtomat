#!/usr/bin/perl
# ---   *   ---   *   ---
# SHADOWLIB
# Shady pre-compiled stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package shadowlib;
  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---

sub take($imports) {
  for my $libpath(keys %$imports) {

    my @modules=@{$imports->{$libpath}};
    for my $module(@modules) {
      `perl -e "use lib '$libpath';use $module;"`;

    };
  };
};

# ---   *   ---   *   ---
1; # ret
