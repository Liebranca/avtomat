#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD TOKEN
# basic unit of meaning
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::Token;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);

  use Arstd::String qw(
    cat
    strip
    has_suffix
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    tokensplit
    tokenshift
    tokenpop
    tokentidy
    semipop
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# gets first token from string
#
# [0]: mem  ptr ; expression hashref
# [<]: byte ptr ; token (new string) | null
#
# [!]: overwrites input mem

sub tokenshift {
  # early exit on blank input
  return null if ! strip($_[0]->{expr});

  # cut at space or word boundary
  my @have=tokensplit($_[0]);

  # get first non-whitespace token
  my $out=shift @have;
     $out=shift @have while ! strip($out);

  # overwrite input
  $_[0]->{expr}=cat(@have);

  return $out;
};


# ---   *   ---   *   ---
# ^gets last token
#
# [0]: mem  ptr ; expression hashref
# [<]: byte ptr ; token (new string) | null
#
# [!]: overwrites input string

sub tokenpop {
  # early exit on blank input
  return null if ! strip($_[0]->{expr});

  # cut at space or word boundary
  my @have=tokensplit($_[0]);

  # get last non-whitespace token
  my $out=pop @have;
     $out=pop @have while ! strip($out);

  # overwrite input
  $_[0]->{expr}=cat(@have);
  return $out;
};


# ---   *   ---   *   ---
# splits expression into tokens
#
# [0]: mem  ptr  ; expression hashref
# [<]: byte pptr ; tokens (new array)
#
# [*]: conserves whitespaces

sub tokensplit {
  return (
    grep {! is_null($ARG)}
    split token_re(),$_[0]->{expr}
  );
};


# ---   *   ---   *   ---
# clears unwanted spaces
#
# [0]: mem  ptr ; expression hashref
# [<]: bool     ; string is not null
#
# [!]: overwrites input string

sub tokentidy {
  return 0 if is_null($_[0]->{expr});

  my $re=qr{\s+};
  $_[0]=~ s[$re][ ]g;

  return strip($_[0]->{expr});
};


# ---   *   ---   *   ---
# basic pattern for splitting
# expressions up
#
# [*]: const
# [<]: re

sub token_re {
  return qr{((?:[\s]+|[^:_[:alnum:]]))}x;
};


# ---   *   ---   *   ---
# gets rid of semicolons at the
# end of a token
#
# [0]: mem  ptr ; expression hashref
# [<]: bool     ; string is not null
#
# [!]: overwrites input string

sub semipop {
  return 0 if is_null($_[0]->{expr});

  my $semi_re=qr{\s*;\s*$};
  $_[0]->{expr}=~ s[$semi_re][]sm;

  return ! is_null($_[0]->{expr});
};


# ---   *   ---   *   ---
1; # ret
