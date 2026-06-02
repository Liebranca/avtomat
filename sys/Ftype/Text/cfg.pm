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
  use Chk qw(is_null is_arrayref);
  use Arstd::String qw(strip wstrip gsplit);
  use Arstd::peso qw(pefex);
  use Arstd::seq qw(seqstrip);
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::throw;

  use parent 'Ftype::Text';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4a';
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
      $class->rd_flush(\@out,$key,$value,$strar);

      # ^get new value
      $key   = $tmp;
      $value = $line;

      # process key
      wstrip($key);
      unstrtok($key,$strar);

    # catch null key ;>
    } elsif(is_null($key)) {
      throw "cfg: key for '$line' is null";

    # ^nope, cat to existing
    } else {
      $value .= " $line";
    };
  };

  # dump last value
  $class->rd_flush(\@out,$key,$value,$strar);

  # give [key=>value] pairs
  return @out;
};


# ---   *   ---   *   ---
# evaluate and save value
# recurses when needed

sub rd_flush {
  my ($class,$out,$key,$value,$strar)=@_;
  return if ! $key;

  my @nest=$class->rd_nest($value,$strar);
  if(@nest) {
    push @$out,$key=>[@nest];

  } else {
    push @$out,$key=>[pefex($value,$strar)];
  };

  return;
};

# ---   *   ---   *   ---
# ^does the recursion

sub rd_nest {
  my ($class,$value,$strar)=@_;

  # value is a token...
  my $tok_re=Arstd::seq::tok_re();
  return () if! ($value=~ qr{^ *$tok_re *$});

  # ^of 'scope' type...
  my ($type,$idex)=($+{type},$+{idex});
  return () if $type ne 'SCP';

  # ^and the delimiter is `[]` brackets
  my $ct=$strar->[$idex];
  return () if! ($ct=~ qr{^\[});

  # if so, then recurse
  seqstrip({beg=>'[',end=>']'},$ct);
  my @out=$class->rd($ct);

  unstrtok($ARG,$strar) for @out;
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
