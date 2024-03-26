#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:CMDLIB
# Where the defs at?
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmdlib;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Arstd::PM;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  list => [qw(
    rd::cmdlib::macro
    rd::cmdlib::asm
    rd::cmdlib::dd

  )],

  next_link => 'ipret::cmdlib',

};

# ---   *   ---   *   ---
# fetch definitions from
# sub-packages

sub load($class,$main) {

  map {

    # fetch pkg
    cloadi $ARG;
    my $tab=$ARG->build($main);

    # extract cstruc args
    {values %$tab};


  } @{$class->list};

};

# ---   *   ---   *   ---
1; # ret
