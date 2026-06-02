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
  use Arstd::String qw(wstrip gstrip gsplit ident);
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    peval
    pevals
    pefex
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub esc_re {
  return qr{\$: \s*
    (?<on>[%/]?) \s*
    (?<body>
      (?: [^;] | ;[^>])*?
      ;*?

    ) \s*

  ;>}x,
};


# ---   *   ---   *   ---
# peso rules: first token is command ;>

sub getcmd {
  return gsplit($_[0],qr" +");
};


# ---   *   ---   *   ---
# like eval, but conscious of peso escapes
# and string tokenization
#
# [0]: byte ptr  ; value to eval
# [1]: byte pptr ; array of token contents
#                  (for unstrtok)
#
# [<]: any ; result of eval [value]

sub peval {
  # get final values
  my ($s,$ar)=peval_prologue(@_);
  unstrtok($s,$ar);

  my @out=eval($_[0]);

  # we forbid undefined return values,
  # else catching syntax errors would be
  # a downright nightmare
  throw "PEVAL eq UNDEF {\n"
  .     ident($_[0],1)
  .     "\n}"

  if    int grep {! defined $ARG} @out;

  return @out;
};


# ---   *   ---   *   ---
# prefix for the ipret

sub peval_prologue {
  # default token array to empty
  my ($s,$ar)=@_;
  $ar //= [];

  # run peso escapes
  pesc_ipret($ARG,$ar) for @$ar;

  return ($s,$ar);
};


# ---   *   ---   *   ---
# like peval, but always gives you
# an array of strings
#
# [0]: byte ptr  ; value to eval
# [1]: byte pptr ; array of token contents
#                  (for unstrtok)
#
# [<]: byte pptr ; result of eval [value]

sub pevals {
  my ($s,$strar)=peval_prologue(@_);
  wstrip($s);

  my @out=gstrip($s,qr" +");
  unstrtok($ARG,$strar) for @out;

  return @out;
};


# ---   *   ---   *   ---
# ^same thing plus file expansion

sub pefex {
  my ($s,$strar)=peval_prologue(@_);
  wstrip($s);

  my @out=gstrip($s,qr" +");
  unstrtok($ARG,$strar,'str') for @out;

  @out=(
    grep {$ARG && $ARG ne '+)'}
    map  {glob($ARG)} @out
  );
  unstrtok($ARG,$strar) for @out;

  return @out;
};


# ---   *   ---   *   ---
# interprets peso escapes

sub pesc_ipret {
  # pass if value isn't a peso escape
  my $re=esc_re();
  return 0 if ! ($_[0]=~ qr{^$re$});

  # ^else continue
  my ($on,$body)=($+{on},$+{body});
  $on //= null;

  # tokenize strings within command
  my $strar=[];
  strtok($strar,$body);

  # ^now eval it
  my $out=null;
  my ($cmd,@args)=getcmd($body);
  if($cmd eq 'asis') {
    $out=join ' ',@args;
    unstrtok($out,$strar);

  # invalid command
  } else {
    throw "peso: invalid command '$cmd'";
  };
  # replace and give
  $_[0]=~ s[$re][$out];
  return 1;
};


# ---   *   ---   *   ---
# ret

1;
