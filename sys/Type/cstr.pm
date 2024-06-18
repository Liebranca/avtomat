#!/usr/bin/perl
# ---   *   ---   *   ---
# C STRING
# Mother of segfaults
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Type::cstr;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use List::Util qw(sum);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Type;
  use Bpack;

  use Arstd::Bytes;
  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(cstrlen);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  mask => [
    0x7F7F7F7F7F7F7F7F,
    0x0101010101010101,
    0x8080808080808080,

  ],

  xword_re => qr{^([xyz])word$},

};

# ---   *   ---   *   ---
# get length of a C string
# if chars in 00-7E range
# else bogus

sub len($sref) {


  # get ctx
  my $class = St::cpkg;

  my $mask  = $class->mask;
  my $re    = $class->xword_re;


  # get buf/chunk sizes
  my $size  = length $$sref;
  my @type  = map {

    if($ARG=~ $re) {

      my $key=$1;
      my $cnt={
        x => 2,
        y => 4,
        z => 8,

      }->{$key};

      ('qword') x $cnt;

    } else {$ARG};

  } typeof $size;


  # read chunks until null found
  my $len   = 0;
  my $xlen  = 0;
  my $nterm = 0;

  while(@type) {


    # read next chunk
    my $fmat = shift @type;

    my $word = bunpack $fmat,$sref,$len;
       $word = $word->{ct}->[0];


    # black magic
    $xlen  = 0;

    $word ^= $mask->[0];
    $word += $mask->[1];
    $word &= $mask->[2];

    goto bot if ! $word;


    # add idex of first null byte
    $xlen   = bitscanf $word;
    $xlen >>= 3;

    $len   += $xlen;
    $nterm  = 1;

    last;


    # ^no null, add sizeof
    bot:
    $len += sizeof $fmat;

  };


  return $len-$nterm;

};

# ---   *   ---   *   ---
# exporter names

  *cstrlen = *len;

# ---   *   ---   *   ---
1; # ret
