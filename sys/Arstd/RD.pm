#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD RD
# A reader of bins
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::RD;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::IO;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(
    fstin

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get hashref from unpack

sub fstin($sref,@order) {

  # get [keys],[format strings]
  my @name=array_keys(\@order);
  my @fmat=array_values(\@order);

  # ^apply unpack
  my @values=();
  csume($sref,\@values,@fmat);

  # ^make [name=>value] hashref
  my $out={ map {
    (shift @name) => $ARG

  } @values };

  return $out;

};

# ---   *   ---   *   ---
1; # ret
