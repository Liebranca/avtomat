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
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::Hash;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Chk qw(is_hashref is_null);
  use Arstd::String qw(gstrip);
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    gvalues
    lfind
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# cstruc

sub new($class,%args) {
  return bless {%args},$class;
};


# ---   *   ---   *   ---
# give keys if they are in the hash
# AND if their values are not null

sub gvalues {
  my $h=shift;
  return grep {
      exists($h->{$ARG})
  &&! is_null($h->{$ARG})

  } @_;
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

  # make copy?
  if($O{duplicate}) {
    %$h=(%$h,reverse %$h);

  # ^nope, overwrite!
  } else {
    %$h=reverse %$h;

  };

  return $h;
};


# ---   *   ---   *   ---
# returns shallow copy of hash

sub cpy($h) {
  my $cpy={};
  for my $key(keys %$h) {
    $cpy->{$key}=$h->{$key};
  };

  if(is_blessed($h)) {
    $cpy=bless $cpy,ref $h;
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
  throw "No such $name: $key";
};


# ---   *   ---   *   ---
# sets out unset values

sub defaults($h,%O) {
  for my $key(keys %$h) {
    $O{$key} //= $h->{$key};
  };
  return;
};


# ---   *   ---   *   ---
# ^both

sub vdef($h,%O) {
  $h->validate(%O);
  $h->defaults(%O);
  return;
};


# ---   *   ---   *   ---
# give key=>value from key

sub kv($h,$key) {
  return $key=>$h->{$key};
};


# ---   *   ---   *   ---
# make hash from string ;>

sub hashstr {
  return {map {
    my ($k,$v)=split qr{\s*\=\>\s*},$ARG;
    ($k=>$v);

  } gstrip(split qr"\n",$_[0])};
};


# ---   *   ---   *   ---
1; # ret
