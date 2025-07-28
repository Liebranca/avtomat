#!/usr/bin/perl
# ---   *   ---   *   ---
# FTYPE
# Stuff assoc'd to extensions
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype;
  use v5.42.0;
  use strict;
  use warnings;

  use Carp;
  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;
  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# GBL

  my $Cache={};


# ---   *   ---   *   ---
# ^add entry

sub register($class,$ice) {
  no strict 'refs';
  my $subclass="$class\::$ice->{name}";
  $Cache->{$subclass}=$ice;

  # yes
  *$subclass=sub {return $ice};

  return;

};


# ---   *   ---   *   ---
# ^fetch

sub fet($class,$name) {
  return $Cache->{$name};

};


# ---   *   ---   *   ---
# get ftype ice from filename

sub ext_to_ftype($file) {
  my @path=split qr{\/},$file;
  return undef if ! @path;

  map {
    return $ARG if $path[-1]=$ARG->{ext};

  } values %$Cache;


  return undef;

};


# ---   *   ---   *   ---
1; # ret
