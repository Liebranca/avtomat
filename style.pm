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
package style;

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

    $NULL
    $NULLSTR
    $FREEBLOCK

    $AR_WARNING
    $ERROR
    $FATAL

    $COMMA_RE
    $SPACE_RE
    $COLON_RE
    $NEWLINE_RE

    STRERR

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.1;
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

  Readonly our $NULLSTR=>q();

# ---   *   ---   *   ---

  Readonly our $AR_WARNING=>"\e[33;22m";
  Readonly our $ERROR=>"\e[35;1m";
  Readonly our $FATAL=>"\e[31;1m";

# ---   *   ---   *   ---

  Readonly our $COMMA_RE=>qr{,};
  Readonly our $SPACE_RE=>qr{\s};
  Readonly our $COLON_RE=>qr{:};
  Readonly our $NEWLINE_RE=>qr{\n};

# ---   *   ---   *   ---
# utility calls

sub STRERR($info=$NULLSTR) {

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
