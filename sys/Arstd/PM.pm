#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD PM
# Perl module utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::PM;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/';
  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Mach;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get subs of module

sub subsof($class) {

  no strict 'refs';

  my %tab   = %{"$class\::"};
  my @names = grep {
    defined &{$tab{$ARG}}

  } keys %tab;

  return map {$ARG=>$class} @names;

};

# ---   *   ---   *   ---
# ^give subs of multiple modules,
# popping any duplicates

sub subsof_dupop(@classes) {
  return map {subsof($ARG)} @classes;

};

# ---   *   ---   *   ---
# ^subroutines of modules
# if they don't exist in main

sub subsof_merge($main,@classes) {

  my %subs = subsof($main);
  my %ext  = subsof_dupop(@classes);

  my @add  = grep {! exists $subs{$ARG}} keys %ext;

  return map {$ARG=>$ext{$ARG}} @add;

};

# ---   *   ---   *   ---
# ^actually add them to main

sub submerge($main,$classes,%O) {

  # defaults
  $O{-x} //= $NO_MATCH;

  # get [symbol=>module]
  my %subs=subsof_merge($main,@$classes);

  # ^filter out excluded subs
  my @filt=grep {
    ! ($ARG=~ $O{-x})

  } keys %subs;

  # ^add symbols to namespace
  no strict 'refs';

  map {
    *{"$main\::$ARG"}=*{"{$subs{$ARG}\::$ARG"};

  } @filt;

  return @filt;

};

# ---   *   ---   *   ---
# test

map {say $ARG} submerge(

  'Arstd::PM',
  [qw(Mach)],

  -x=>qr{^(?:throw_|err)}x,

);

# ---   *   ---   *   ---
1; # ret
