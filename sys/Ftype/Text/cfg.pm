#!/usr/bin/perl
# ---   *   ---   *   ---
# CFG
# simplified config file format
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::cfg;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Arstd::String qw(strip wstrip gsplit);
  use Arstd::peso qw(peval);
  use Arstd::seq;
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::throw;

  use parent 'Ftype::Text';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# make ice

sub classattr {return {
  name => 'cfg',
  ext  => '\.cfg$',
  lcom => '#',
  hed  => '\%cfg;',
  mag  => '\$:get0x25;>',

  highlight=>[
    qr{\%cfg;}  => 0x0E,
    qr{^[^:]+:} => 0x04,
  ],
}};


# ---   *   ---   *   ---
# entry point

sub rd {
  my $class=shift;

  # tokenize strings
  my $strar=[];
  strtok($strar,$_[0],syx=>strtok_syx());

  # walk lines to find [key:value] pairs
  my @out          = ();
  my $key_re       = qr{^([^:]+?):};
  my ($key,$value) = (null,null);

  for my $line(gsplit($_[0],"\n")) {
    # beggining of new value?
    if($line=~ s[$key_re][]) {
      my $tmp=$1;

      # dump existing value
      if($key) {
        wstrip($value);
        unstrtok($value,$strar);

        push @out,$key=>peval($value);
      };

      # ^get new value
      $key   = $1;
      $value = $line;

      # process key
      wstrip($key);
      unstrtok($key,$strar);

    # catch null key ;>
    } elsif(is_null($key)) {
      throw "cfg: key for '$line' is null";

    # ^nope, cat to existing
    } else {
      $value .= $line;
    };
  };

  # dump last value
  if($key) {
    wstrip($value);
    unstrtok($value,$strar);

    push @out,$key=>peval($value);
  };

  # give [key=>value] pairs
  return @out;
};


# ---   *   ---   *   ---
# syntax rules for strtok

sub strtok_syx {
  return [
    @{Arstd::strtok::defsyx()},
    values %{Arstd::seq::delim()}
  ];
};


# ---   *   ---   *   ---
1; # ret
