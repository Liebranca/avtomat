#!/usr/bin/perl
# ---   *   ---   *   ---
# CHECK
# Common conditionals
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Chk;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;
  use Arstd;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use Inlining;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    is_hashref
    is_coderef
    is_arrayref
    is_qre

    stripline

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $ARRAYREF_RE=>qr{
    ^ARRAY\(0x[0-9a-f]+\)

  }x;

  Readonly our $CODEREF_RE=>qr{
    ^CODE\(0x[0-9a-f]+\)

  }x;

  Readonly our $HASHREF_RE=>qr{
    ^HASH\(0x[0-9a-f]+\)

  }x;

  Readonly our $QRE_RE=>qr{\(\?\^u(?:[xsmg]*):}x;
  Readonly our $STRIPLINE_RE=>qr{\s+|:__NL__:}x;

# ---   *   ---   *   ---

;;sub is_coderef :inlined ($v) {
  length ref $v && ($v=~ $Chk::CODEREF_RE);

};sub is_arrayref :inlined ($v) {
  length ref $v && ($v=~ $Chk::ARRAYREF_RE);

};sub is_hashref :inlined ($v) {
  length ref $v && ($v=~ $Chk::HASHREF_RE);

};sub is_qre :inlined ($v) {
  defined $v && ($v=~ $Chk::QRE_RE);

};

# ---   *   ---   *   ---
# remove all whitespace

sub stripline :inlined ($s) {
  join $NULLSTR,(split $Chk::STRIPLINE_RE,$s);

};

# ---   *   ---   *   ---
1; # ret
