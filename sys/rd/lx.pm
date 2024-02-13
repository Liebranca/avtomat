#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX
# Slow runner ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::lx;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Re;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# names of execution rounds

sub passes($class) { return qw(
  parse

)};

# ---   *   ---   *   ---
# default set of commands

sub cmdset($class) { return {
  echo => 1,
  stop => 1,

}};

# ---   *   ---   *   ---
# get name of current pass

sub passname($class,$rd) {
  return ($class->passes())[$rd->{pass}];

};

# ---   *   ---   *   ---
# test commands

sub echo_parse($rd,$branch) {

  map {
    print {*STDERR} $ARG->{value};

  } @{$branch->{leaves}};

  say $NULLSTR;

};

sub stop_parse($rd,$branch) {
  $rd->perr('STOP');

};

# ---   *   ---   *   ---
# generate/fetch command table

sub load_CMD($class) {

  state $cmdset = $class->cmdset();
  state @keys   = keys %$cmdset;

  state $CMD    = {

    ( map {

      # get name of command
      my $key   = $ARG;
      my $value = ($cmdset->{$key} ne 1)
        ? $cmdset->{$key}
        : $key
        ;

      # get subroutine variants of
      # command per execution layer
      $key => { map { $ARG => codefind(
        $class,"${key}_$ARG"

      )} $class->passes() },


    } @keys ),


    -re=>re_eiths(

      \@keys,

      bwrap=>1,
      whole=>1

    ),

  };


  return $CMD;

};

# ---   *   ---   *   ---
1; # ret
