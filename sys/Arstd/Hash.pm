#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD HASH
# Utils for em
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd::Hash;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Chk;
  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    lfind

    hash_invert
    hash_cpy

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,%args) {
  return bless {%args},$class;

};

# ---   *   ---   *   ---
# find hashkeys in list
# returns matches ;>

sub lfind($h,$l) {

  if(!is_hashref($h)) {
    $h=map {$ARG=>1} @$h;

  };

  return [grep {exists $h->{$ARG}} @$l];

};

# ---   *   ---   *   ---
# make [key=>value] into [value=>key]
# optionally [key=>value,value=>key]

sub invert($h,%O) {

  # defaults
  $O{duplicate}//=0;

# ---   *   ---   *   ---

  if($O{duplicate}) {
    %$h=(%$h,reverse %$h);

  } else {
    %$h=reverse %$h;

  };

  return $h;

};

# ---   *   ---   *   ---
# returns exact copy of hash

sub cpy($h) {

  my $cpy={};
  for my $key(keys %$h) {
    $cpy->{$key}=$h->{$key};

  };

  if(Arstd::Hash->is_valid($h)) {
    $cpy=bless $cpy,$h->get_class();

  };

  return $cpy;

};

# ---   *   ---   *   ---
# exporter names

  *hash_cpy=*cpy;
  *hash_invert=*invert;

# ---   *   ---   *   ---
1; # ret
