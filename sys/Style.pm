#!/usr/bin/perl
# ---   *   ---   *   ---
# STYLE
# Boilerpaste for constants
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Style;
  use v5.42.0;
  use strict;
  use warnings;

  use Readonly;

  use Carp;
  use English;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    $NOOP
    $NO_MATCH
    $ANY_MATCH

    $AR_WARNING
    $AR_ERROR
    $AR_FATAL

    $DOT_RE
    $SEMI_RE
    $COMMA_RE
    $SPACE_RE
    $NSPACE_RE
    $COLON_RE
    $DCOLON_RE
    $BOR_RE
    $ATILDE_RE
    $NEWLINE_RE
    $FSLASH_RE
    $MODULO_RE
    $ASTER_RE
    $NUM_RE

    strerr
    catar

    null
    noop

  );

# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.02.8';
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub noop {};
  sub null {return ''};

  Readonly our $NOOP       => \&nop;

  Readonly our $AR_WARNING => "\e[33;22m";
  Readonly our $AR_ERROR   => "\e[35;1m";
  Readonly our $AR_FATAL   => "\e[31;1m";

  Readonly our $DOT_RE     => qr{\.};
  Readonly our $SEMI_RE    => qr{;};
  Readonly our $COMMA_RE   => qr{,};
  Readonly our $SPACE_RE   => qr{\s};
  Readonly our $NSPACE_RE  => qr{\s+};
  Readonly our $COLON_RE   => qr{:};
  Readonly our $DCOLON_RE  => qr{::};
  Readonly our $BOR_RE     => qr{\|};
  Readonly our $ATILDE_RE  => qr{\~};
  Readonly our $NEWLINE_RE => qr{\n};
  Readonly our $FSLASH_RE  => qr{/};
  Readonly our $MODULO_RE  => qr{\%};
  Readonly our $ASTER_RE   => qr{\*};
  Readonly our $NUM_RE     => qr{^\d+$};

  Readonly our $NO_MATCH   => qr{\b\B};
  Readonly our $ANY_MATCH  => qr{.+};


# ---   *   ---   *   ---
# utility calls

sub strerr($info=null) {
  return (length $info)
    ? "$ERRNO $info"
    : "$ERRNO"
    ;

};


# ---   *   ---   *   ---
# join null,(list)

sub catar(@src) {join null,@src};


# ---   *   ---   *   ---
1; # ret
