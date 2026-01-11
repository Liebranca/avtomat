#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD PESO
# recursive swan song
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::peso;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Arstd::String qw(gsplit ident);
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(peval);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub esc_re {
  return qr{\$: \s*
    (?<on>[%/]?) \s*
    (?<body> (?: [^;] | ;[^>])*?) \s*
  ;>}x,
};


# ---   *   ---   *   ---
# peso rules: first token is command ;>

sub getcmd {
  return gsplit($_[0],qr" +");
};


# ---   *   ---   *   ---
# like eval, but conscious of peso escapes

sub peval {
  my $re=esc_re();

  # non escaped value uses standard perl eval
  if(! ($_[0]=~ qr{^$re$})) {
    my $out=eval($_[0]);

    # we forbid undefined return values,
    # else catching syntax errors would be
    # a downright nightmare
    throw "PEVAL eq UNDEF" if! defined $out;
    return $out;
  };

  # ^escaped values get the extra proc
  my ($on,$body)=($+{on},$+{body});
  $on //= null;

  # tokenize strings within command
  my $strar=[];
  strtok($strar,$body);

  # ^now eval it
  my ($cmd,@args)=getcmd($body);
  if($cmd eq 'asis') {
    my $s=join ' ',@args;
    unstrtok($s,$strar);

    return $s;
  };
  # invalid command
  throw "peval: invalid command '$cmd'";
};


# ---   *   ---   *   ---
1; # ret
