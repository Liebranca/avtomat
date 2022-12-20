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

    hexn  => qr{\$  [0-9A-Fa-f\.:]+}x,
    octn  => qr{\\ [0-7\.:]+}x,
    binn  => qr{0b  [0-1\.:]+}x,
    decn  => qr{[0-9\.:]+}x,

    term  => Lang::nonscap(';'),
    sep   => Lang::nonscap(','),

  };

  my $HEX={

    name => $REGEX->{hexn},
    fn   => 'capt',

  };

  my $OCT={

    name => $REGEX->{octn},
    fn   => 'capt',

  };

  my $BIN={

    name => $REGEX->{binn},
    fn   => 'capt',

  };

  my $DEC={

    name => $REGEX->{decn},
    fn   => 'capt',

  };

  my $NUM={

    name => 'num',
    fn   => 'rdnum',

    dom  => 'Grammar::peso',

    chld => [

      $HEX,$Grammar::OR,
      $OCT,$Grammar::OR,
      $BIN,$Grammar::OR,

      $DEC

    ],

  };

  my $COMMA={

    name => $REGEX->{sep},
    fn   => 'rew',

    opt  => 1,

  };

  my $TERM={

    name => $REGEX->{term},
    fn   => 'term',

  };

# ---   *   ---   *   ---
# global state

  our $Top;

# ---   *   ---   *   ---

sub rdnum($tree,$match) {

  state %converter=(

    hexn=>\&Lang::pehexnc,
    octn=>\&Lang::peoctnc,
    binn=>\&Lang::pebinnc,

  );

  for my $type(keys %converter) {

    my $fn=$converter{$type};

    map {

      $ARG->{value}=$fn->(
        $ARG->{value}

      );

    } $match->branches_in(
      $REGEX->{$type}

    );

  };

};

# ---   *   ---   *   ---

  Grammar::peso->mkrules({

    name=>'ex',
    chld=>[$NUM,$COMMA,$TERM],

  });

  my $t=Grammar::peso->parse(q[
    0b10,\10,$10,10;

  ]);

  $t->prich();

# ---   *   ---   *   ---
1; # ret
