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
# lyeb,
# ---   *   ---   *   ---

# deps
package Style;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Carp;
  use English qw(-no_match_vars);

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    $MEMPTR
    $MEMPTR_SZBYTE
    $MEMPTR_SZMASK

    $NOOP
    $NO_MATCH
    $ANY_MATCH

    $NULL
    $NULLSTR
    $FREEBLOCK

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

    strerr

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.4;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $NOOP=>sub {};

  Readonly our $MEMPTR=>0x9E5024<<40;

  Readonly our $MEMPTR_SZBYTE=>0xFF<<32;
  Readonly our $MEMPTR_SZMASK=>0x08<<32;

  Readonly our $NULL=>

    $MEMPTR
  | $MEMPTR_SZMASK
  | 0xDEADBEEF
  ;

  Readonly our $FREEBLOCK=>

    $MEMPTR
  | $MEMPTR_SZMASK
  | 0xF9EEB10C

  ;

  Readonly our $NULLSTR=>q[];

# ---   *   ---   *   ---

  Readonly our $AR_WARNING => "\e[33;22m";
  Readonly our $AR_ERROR   => "\e[35;1m";
  Readonly our $AR_FATAL   => "\e[31;1m";

# ---   *   ---   *   ---

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

  Readonly our $NO_MATCH   => q{$^};
  Readonly our $ANY_MATCH  => qr{.+};

# ---   *   ---   *   ---
# utility calls

sub strerr($info=$NULLSTR) {

  my $out;

  if(length $info) {
    $out="$ERRNO $info";

  } else {
    $out="$ERRNO";

  };

  return $out;

};

# ---   *   ---   *   ---
1; # ret
