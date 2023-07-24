#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH MICRO
# Ops that do little
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::Micro;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);
  use List::Util qw(min);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    -autoload=>[qw()],

  }};

# ---   *   ---   *   ---
# GBL

# ---   *   ---   *   ---
# copy value from src to dst

sub cpy($dst,$src) {
  $dst->set(str=>${$src->{buf}});

};

# ---   *   ---   *   ---
# ^idem, but clear src

sub mov($dst,$src) {
  $dst->set(str=>${$src->{buf}});
  $src->set(num=>0x00);

};

# ---   *   ---   *   ---
# ^swap them out

sub wap($dst,$src) {

  my $tmp=${$dst->{buf}};

  $dst->set(str=>${$src->{buf}});
  $src->set(str=>$tmp);

};

# ---   *   ---   *   ---
# inplace binary template
# iceofs follow

sub _impbin_temple($dst,$src,$op) {

  # get operand word size
  my $width=min(
    $dst->{cap},
    $src->{cap}

  ) * 8;

  $width=min($width,64);

  # ^extract words
  my @a=$dst->to_bytes($width);
  my @b=$src->to_bytes($width);

  map {eval
    '$a[$ARG]' . $op . '$b[$ARG];'

  } 0..min($#a,$#b);

  $dst->from_bytes(\@a,$width);

};

# ---   *   ---   *   ---
# ^bin or/xor

sub bor($dst,$src) {
  _impbin_temple($dst,$src,'|=');

};

sub bxor($dst,$src) {
  _impbin_temple($dst,$src,'^=');

};

# ---   *   ---   *   ---
# ^bin and/nand

sub band($dst,$src) {
  _impbin_temple($dst,$src,'&=');

};

sub bnand($dst,$src) {
  _impbin_temple($dst,$src,'&=~');

};

# ---   *   ---   *   ---
# shift left/right

sub bshl($dst,$src) {
  _impbin_temple($dst,$src,'<<=');

};

sub bshr($dst,$src) {
  _impbin_temple($dst,$src,'>>=');

};

# ---   *   ---   *   ---
1; # ret
