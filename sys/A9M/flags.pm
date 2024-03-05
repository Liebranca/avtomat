#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M FLAGS
# The bits that guide us!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::flags;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Bitformat;

  use Arstd::Array;

  use parent 'A9M::component';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  tab   => [
    public => 0,
    const  => 0,
    static => 0,

  ],

  ivtab => {

    public   => [public => 1],
    const    => [const  => 1],
    static   => [static => 1],

    private  => [public => 0],
    volatile => [const  => 0],
    dynamic  => [static => 0],

  },


  list  => sub {[array_keys $_[0]->tab()]},

  fmat => sub {

    Bitformat 'A9M-flags',

    map {$ARG => 1}
    @{$_[0]->list()}

  },

};

# ---   *   ---   *   ---
# give [key=>defv] for each
# input key
#
# gives whole table if no input!

sub default($class,@keys) {


  return @{$class->tab()} if ! @keys;


  my $tab=$class->ivtab();

  map {

     $tab->{$ARG}->[0]
  => $tab->{$ARG}->[1]

  } @keys;

};

# ---   *   ---   *   ---
# ^paste attrs on object

sub defnit($class,$ice,@keys) {

  my %flags=$class->default(@keys);

  map  {$ice->{$ARG}=$flags{$ARG}}
  keys %flags;


  return;

};

# ---   *   ---   *   ---
1; # ret
