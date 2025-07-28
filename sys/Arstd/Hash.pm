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
  use v5.42.0;
  use strict;
  use warnings;

  use Carp;
  use English;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;
  use Chk;
  use Arstd::String;

  use parent 'St';


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    lfind

    hash_invert
    hash_cpy

    hashstr

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# constructor

sub new($class,%args) {
  return bless {%args},$class;

};


# ---   *   ---   *   ---
# find hashkeys in list
# returns matches ;>

sub lfind($h,$l) {
  $h={map {$ARG=>1} @$h}
  if ! is_hashref $h;

  return [grep {exists $h->{$ARG}} @$l];

};


# ---   *   ---   *   ---
# make [key=>value] into [value=>key]
# optionally [key=>value,value=>key]

sub invert($h,%O) {

  # defaults
  $O{duplicate}//=0;


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
# validate struc

sub validate($h,%O) {

  for my $key(keys %O) {
    throw_nos('key',$key)
    if !exists $h->{$key};

  };

};


# ---   *   ---   *   ---
# ^errme

sub throw_nos($name,$key) {
  croak "No such $name: $key";

};


# ---   *   ---   *   ---
# sets out unset values

sub defaults($h,%O) {

  for my $key(keys %$h) {
    $O{$key} //= $h->{$key};

  };

};


# ---   *   ---   *   ---
# ^both

sub vdef($h,%O) {
  $h->validate(%O);
  $h->defaults(%O);

};


# ---   *   ---   *   ---
# give key=>value from key

sub kv($h,$key) {
  return $key=>$h->{$key};

};


# ---   *   ---   *   ---
# make hash from string ;>

sub hashstr {

  return {

    map {
      my ($k,$v)=split qr{\s*\=\>\s*},$ARG;
      ($k=>$v);

    } grep  {strip \$ARG;length $ARG}
      split $NEWLINE_RE,$_[0]

  };

};


# ---   *   ---   *   ---
# exporter names

  *hash_cpy    = *cpy;
  *hash_invert = *invert;
  *hash_kv     = *kv;


# ---   *   ---   *   ---
1; # ret
