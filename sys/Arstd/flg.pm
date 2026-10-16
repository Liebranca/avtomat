#!/usr/bin/perl
# ---   *   ---   *   ---
# FLAGS
# they fly
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::flg;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT_OK=qw(
    flg_def
    flg_get
    flg_or
    flg_and
    flg_knot
    flg_xor
  );


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.00.1a";
  my $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# cstruc tab
#
# [0]: byte pptr ; names
# [<]: mem ptr   ; [name=>value] table

sub flg_def {
  my $i=0;
  return {map {$ARG=>1 << $i++} @_};
};


# ---   *   ---   *   ---
# ^get values from tab
#
# [0]: mem ptr   ; [name=>value] table
# [1]: byte pptr ; names
#
# [<]: qword ptr ; values

sub flg_get {
  return map {
    (exists $_[0]->{$ARG})
      ? $_[0]->{$ARG}
      : 0x00
      ;
  } @_[1..$#_];
};


# ---   *   ---   *   ---
# bitwise ops
#
# [0]: qword     ; dst
# [1]: mem ptr   ; [name=>value] table
# [2]: byte pptr ; names
#
# [<]: qword ; dst
# [!]: modifies destination

sub flg_or {
  $_[0] |= $ARG for flg_get(@_[1..$#_]);
  return $_[0];
};
sub flg_and {
  my $mask=0x00;
     $mask=flg_or($mask,@_[1..$#_]);

  $_[0] &= $mask;
  return $_[0];
};
sub flg_knot {
  my $mask=0x00;
     $mask=flg_or($mask,@_[1..$#_]);

  $_[0] &= ~$mask;
  return $_[0];
};
sub flg_xor {
  my $mask=0x00;
     $mask=flg_or($mask,@_[1..$#_]);

  $_[0] ^= $mask;
  return $_[0];
};


# ---   *   ---   *   ---
1; # ret


