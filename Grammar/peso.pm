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

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use Lang;
  use parent 'Grammar';

# ---   *   ---   *   ---
# ROM

  Readonly my $REGEX=>{

    hexn  => qr{\$  [0-9A-Fa-f\.:]+}x,
    octn  => qr{\\ [0-7\.:]+}x,
    binn  => qr{0b  [0-1\.:]+}x,
    decn  => qr{[0-9\.:]+}x,

    term  => Lang::nonscap(';'),
    sep   => Lang::nonscap(','),

    vname => qr{

      [_A-Za-z][_A-Za-z0-9:\.]*

    }x,

    type  => Lang::eiths(

    [qw(

      byte wide brad word
      unit half line page

      nihil stark signal

    )],

      bwrap=>1

    ),

    spec  => Lang::eiths(

    [qw(

      ptr fptr str buf tab

    )],

      bwrap=>1

    ),

  };

# ---   *   ---   *   ---
# numerical notation

  Readonly my $HEX=>{
    name => $REGEX->{hexn},
    fn   => 'capt',

  };

  Readonly my $OCT=>{
    name => $REGEX->{octn},
    fn   => 'capt',

  };

  Readonly my $BIN=>{
    name => $REGEX->{binn},
    fn   => 'capt',

  };

  Readonly my $DEC=>{
    name => $REGEX->{decn},
    fn   => 'capt',

  };

# ---   *   ---   *   ---
# ^combined into a single rule

  Readonly my $NUM=>{

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

# ---   *   ---   *   ---
# lets call these "syntax ops"

  Readonly my $CLIST=>{

    name => $REGEX->{sep},
    fn   => 'rew',

    opt  => 1,

  };

  Readonly my $TERM=>{
    name => $REGEX->{term},
    fn   => 'term',

  };

# ---   *   ---   *   ---

  Readonly my $TYPE=>{
    name => $REGEX->{type},
    fn   => 'capt',

  };

  Readonly my $SPEC=>{
    name => $REGEX->{spec},
    fn   => 'capt',

    opt  => 1,

  };

  Readonly my $VNAME=>{
    name => $REGEX->{vname},
    fn   => 'capt',

  };

# ---   *   ---   *   ---

  Readonly my $FULL_TYPE=>{
    name => 'type',
    chld => [$TYPE,$SPEC],

  };

  Readonly my $NLIST=>{
    name => 'vnames',
    chld => [$VNAME,$CLIST],

  };

  Readonly my $VLIST=>{

    name => 'values',

    fn   => 'list_flatten',
    dom  => 'Grammar::peso',

    chld => [$NUM,$CLIST],

  };

# ---   *   ---   *   ---
# ^combo

  Readonly my $PTR_DECL=>{

    name => 'ptr_decl',

    fn   => 'ptr_decl',
    dom  => 'Grammar::peso',

    chld => [

      $FULL_TYPE,

      $NLIST,
      $VLIST,

      $TERM

    ],

  };

# ---   *   ---   *   ---
# global state

  our $Top;

# ---   *   ---   *   ---
# converts all numerical
# notations to decimal

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
# turns trees with the structure:
#
# ($match)
# \-->subtype
# .  \-->value
#
# into:
#
# ($match)
# \-->value

sub list_flatten($tree,$match) {

  for my $branch(@{$match->{leaves}}) {
    $branch->flatten_branch();

  };

};

# ---   *   ---   *   ---

sub ptr_decl($tree,$match) {

  use Fmat;
  fatdump($match->bhash(1,1,1));

};

# ---   *   ---   *   ---
# test

  Grammar::peso->mkrules($PTR_DECL);

  my $t=Grammar::peso->parse(q[
    byte x $00;

  ]);

  $t->prich();

# ---   *   ---   *   ---
1; # ret
