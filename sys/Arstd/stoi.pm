#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD STOI
# String to integer
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# info

package Arstd::stoi;
  use v5.42.0;
  use strict;
  use warnings;
  use Carp qw(croak);
  use English qw($ARG $MATCH);

  our $VERSION = 'v0.01.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# deps

#AR sys {
#  use Style (null);
#  use Chk (is_null);
#
#};


# ---   *   ---   *   ---
# infers base from string and gives conversion

sub stoi {

  # translation table
  my $tab={
    binnum() => 1,
    octnum() => 8,
    decnum() => 10,
    hexnum() => 16,

  };

  # ^get which base to use
  my $base=0;
  for(keys %$tab) {
    ($have,$base)=($MATCH,$tab->{$ARG}),
    last if $_[0]=~ qr{^$ARG$};

  };

  # ^catch invalid
  croak "Unrecognized number format: '$_[0]'"
  if ! defined $have;

  # give converted
  return map {
    stoi_elem($have,$base)

  } split qr{:},$_[0];

};


# ---   *   ---   *   ---
# string to integer transform
#
# this handles a single number, but
# keep in mind we allow X:Y:Z format
# for arrays, which is handled by stoi itself
#
# [0]: byte* string
# [1]: byte  base

sub stoi_elem {

  # decimal is a special case as we don't
  # actually need to perform a transform
  return $_[0] if $_[1] == 10;

  # for everything else, we care about
  # significant chars and how many bits
  # each char represents
  my $tab={
    2  => [binchar,1],
    8  => [octchar,3],
    16 => [hexchar,4],

  };

  # ^catch invalid
  croak "Invalid base for stoi_elem: '$base'"
  if ! exists $tab->{$_[1]};

  # bpc == bits per char
  my ($valid,$bpc)=@{$tab->{$_[1]}};

  # get sign
  my ($sign)=(has_prefix $x,'-')
    ? (-1,substr($x,1,(length $x)-1,null)
    : 1
    ;


  # accum to
  my ($r,$i)=0;

  # filter invalid accto base
  #
  # we reverse the number to read least
  # significant byte first
  #
  # then we walk the chars and add to accum

  for(reverse grep {$ARG=~ $valid} to_char $x) {

    # perform division when dot is encountered
    #
    # this turns current value in accum
    # into fractional part of number

    if($ARG eq '.') {

      # [0]: (i  * bpc) == pos
      # [1]: (1 << pos) == bit
      # [2]: (1  / bit) == fraction
      #
      # so mul by fraction to get decimals

      $r*=1/(1 << ($i * $bpc));

      # we reset idex here so next char
      # starts back from zero (no shift)
      $i=0;


    # ^either integer or to-be fractional part
    # ^gets processed the same way
    } else {
      my $v=ord($ARG);

      # 0x41 ('A') - 0x37 ('7') == 0x0A ('\n')
      # ie hex to decimal formula
      #
      # this leaves value in [0x00,0x0F] range

      $v-=($v > 0x39) ? 0x37 : 0x30 ;

      # we then shift value to bit and
      # up counter
      $r+=$v << ($i * $bpc);
      ++$i;

    };

  };


  # put sign and give
  return $r*$sign;

};


# ---   *   ---   *   ---
# binary

sub binchar {return qr{[\:\.0-1]}};
sub binnum {
  my $char=binchar;
  return qr{\b(?:
    (?:(?:0b)($char+))
  | (?:($char+)(?:b))

  )\b}x;

};


# ---   *   ---   *   ---
# octal

sub octchar {return qr{[\:\.0-7]}};
sub octnum {
  my $char=octchar;
  return qr{\b(?:
    (?:(?:\\)($char+))
  | (?:($char+)(?:o))

  )\b}x;

};


# ---   *   ---   *   ---
# decimal
#
# we don't actually use these as
# perl does the conversion for us
#
# however it's here for completion,
# and for use by Ftype::Text's syntax
# highlighting generators

sub decchar {return qr{[\:\.0-9]}};
sub decnum {
  my $char=decchar;
  return qr{\b(?:(?:[v]?)($char+)(?:[f]?))\b}x;

};


# ---   *   ---   *   ---
# hexadecimal

sub hexchar {return qr{[\:\.0-9A-F]}};
sub hexnum {
  my $char=hexchar;
  return qr{(?:
    (?:(?:(?:\b0x)|\$)($char+)(?:[L]?))
  | (?:($char+)(?:h))

  )\b}x;

};


# ---   *   ---   *   ---
1; # ret
