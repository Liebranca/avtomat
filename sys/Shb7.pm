#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7
# Shell utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7;
  use v5.42.0;
  use strict;
  use warnings;

  use Storable qw(store retrieve);
  use Cwd qw(abs_path);

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Arstd::String qw(catpath);
  use Arstd::Bin qw(moo);
  use Shb7::Path qw(root);
  use Shb7::Find;
  use Shb7::Build;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.02.3';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# loads a file if available
# else regenerates it from a sub

sub load_cache($name,$dst,$call,@args) {
  my ($pkg,$fname)=(caller);
  my $path=cache("$pkg\::$name");

  my $out={};

  if(moo($path,abs_path($fname))) {
    say {*STDERR} (
      'updated ',"\e[32;1m",
      shpath($path),

      "\e[0m"

    );

    $out=$call->(@args);
    store($out,$path);

  } else {
    $out=retrieve($path);
  };


  $$dst=$out;
  return;
};


# ---   *   ---   *   ---
# get shared object data from shwl

sub sofetch($symtab) {
  # walk object files in shwl
  return { map {
    my $obj = $symtab->{object}->{$ARG};
    my $sym = $obj->{function};

    # ^give OBJ => [SYM]
    ($ARG=>[map {
      my $fn    = $sym->{$ARG};
      my $rtype = $fn->{type};

      [$ARG,$rtype,@{$fn->{args}}];

    } keys %$sym]);

  } keys %{$symtab->{object}} };
};


# ---   *   ---   *   ---
1; # ret
