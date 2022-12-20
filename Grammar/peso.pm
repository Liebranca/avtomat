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

package Grammar::peso;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use Lang;
  use parent 'Grammar';

# ---   *   ---   *   ---
# ROM

  my $REGEX={

    nhex  => qr{\$ [0-9A-Fa-f\.:]+}x,
    term  => qr{(?!< \\);}x,

  };

  my $NUM={

    name => $REGEX->{nhex},
    fn   => 'capt',

  };

  my $TERM={

    name => $REGEX->{term},
    fn   => 'term',

  };

# ---   *   ---   *   ---
# global state

  our $Top;

# ---   *   ---   *   ---

  Grammar::peso->mkrules({

    name=>'ex',
    chld=>[$NUM,$TERM],

  });

  my $t=Grammar::peso->parse(q[$10;]);
  $t->prich();

# ---   *   ---   *   ---
1; # ret
