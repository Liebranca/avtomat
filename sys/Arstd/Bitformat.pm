#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD BITFORMAT
# So I don't have to
# MASH bits by hand
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::Bitformat;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_words);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Arstd::Array;
  use Arstd::Int;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,@order) {

  # out attrs
  my $size = {};

  my $mask = {'$:top;>'=>0};
  my $pos  = {'$:top;>'=>0};


  # array as hash
  my $idex   = 0;
  my @keys   = array_keys(\@order);
  my @values = array_values(\@order);

  # ^walk
  map {

    my $bits = $values[$idex++];

    $size->{$ARG}      = $bits;

    $pos->{$ARG}       = $pos->{'$:top;>'};
    $mask->{$ARG}      = (1 << $bits)-1;

    $pos->{'$:top;>'} += $bits;

  } @keys;

  # calc mask for total size
  $mask->{'$:top;>'}=
    (1 << $pos->{'$:top;>'})-1;


  # make ice
  my $self=bless {

    size => $size,
    mask => $mask,

    pos  => $pos,

  };


  return $self;

};

# ---   *   ---   *   ---
# ^ors values accto their
# position in format

sub bor($self,%data) {

  my $out=0x00;

  map {$out |=(

    $data{$ARG}
  & $self->{mask}->{$ARG}

  ) << $self->{pos}->{$ARG}

  } keys %data;


  return $out;

};

# ---   *   ---   *   ---
# ^for strucs larger than 64

sub array_bor($self,%data) {

  my @out=map {0} 0..$self->bytesize() >> 3;

  map {

    my $idex=int_urdiv(
      $self->{pos}->{$ARG},8

    ) >> 3;

    $out[$idex] |=(

      $data{$ARG}
    & $self->{mask}->{$ARG}

    ) << ($self->{pos}->{$ARG} & 0x3F);

  } keys %data;


  return @out;

};

# ---   *   ---   *   ---
# get bytesize of format

sub bytesize($self) {

  return int_urdiv(
    $self->{pos}->{'$:top;>'},8

  );

};


# ---   *   ---   *   ---
1; # ret
