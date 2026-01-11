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
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Arstd::strtok;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# GBL

  my $Cache={SUPER=>{}};
  sub cache {return $Cache};

# ---   *   ---   *   ---
# definition

sub classattr {return {name=>'SUPER'}};


# ---   *   ---   *   ---
# make ice

sub import {
  my ($class)=@_;
  return if defined fet(
    $class,
    $class->classattr()->{name}
  );

  $class->new();
  return;
};


# ---   *   ---   *   ---
# ^add entry

sub register($class,$ice) {
  no strict 'refs';
  my $subclass=($class eq __PACKAGE__)
    ? "$class\::$ice->{name}"
    : $class
    ;

  return if exists $Cache->{$subclass};

  # yes
  $Cache->{$subclass}=$ice;
  *$subclass=sub {return $Cache->{$subclass}};

  use strict 'refs';
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

  for(values %$Cache) {
    return $ARG if $path[-1]=$ARG->{ext};
  };
  return undef;
};


# ---   *   ---   *   ---
# ^ get syntax rules, if any are
#   defined by the filetype
#
# else uses default ones
# (defined by strtok)

sub syxof($file) {
  my $ftype = ext_to_filetype($file);
  my $def   = Arstd::strtok::defsyx();

  return $def if! $ftype
              ||! $ftype->can('strtok_syx');

  return $ftype->strtok_syx();
};


# ---   *   ---   *   ---
1; # ret
