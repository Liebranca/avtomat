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
  use Mach::Seg;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $INS=>[qw(

    cpy   mov
    wap

    bor   bxor
    band  bnand
    bshl  bshr

  )];

# ---   *   ---   *   ---
# adds instructions to table

sub engrave($class,$frame) {

  no strict 'refs';
  my $ins=${"$class\::INS"};

  map {$frame->add($ARG,pkg=>$class)} @$ins;

};

# ---   *   ---   *   ---
# copy seg or imm to reg

sub cpy($reg,$any) {

  my $type=(Mach::Seg->is_valid($any))
    ? 'seg'
    : 'num'
    ;

  $reg->set($type=>$any);

};

# ---   *   ---   *   ---
# ^reg to reg, clears src operand

sub mov($reg0,$reg1) {
  $reg0->set(seg=>$reg1);
  $reg1->set(num=>0x00);

};

# ---   *   ---   *   ---
# ^swap them out

sub wap($reg0,$reg1) {

  my $tmp=${$reg0->{buf}};

  $reg0->set(seg  => $reg1);
  $reg1->set(rstr => $tmp);

};

# ---   *   ---   *   ---
# inplace binary template
# iceofs follow

sub _impbin_temple($dst,$src,$op) {

  state $tab={

    q[|=]  => sub {$_[0] |  $_[1]},
    q[^=]  => sub {$_[0] ^  $_[1]},

    q[&=]  => sub {$_[0] &  $_[1]},
    q[&=~] => sub {$_[0] &~ $_[1]},

    q[<<=] => sub {$_[0] << $_[1]},
    q[>>=] => sub {$_[0] >> $_[1]},

  };

  $op=$tab->{$op};

  if(Mach::Seg->is_valid($src)) {
    _impbin_temple_seg($dst,$src,$op);

  } else {
    _impbin_temple_imm($dst,$src,$op);

  };

};

# ---   *   ---   *   ---
# ^source operand is memory segment

sub _impbin_temple_seg($dst,$src,$op) {

  # get operand word size
  my $width=min(
    $dst->{cap},
    $src->{cap}

  ) * 8;

  # ^cap to word and extract
  $width=min($width,64);

  my @a=$dst->to_bytes($width);
  my @b=$src->to_bytes($width);

  # ^map passed fn to array
  map {
    $a[$ARG]=$op->($a[$ARG],$b[$ARG])

  } 0..min($#a,$#b);

  $dst->from_bytes(\@a,$width);

};

# ---   *   ---   *   ---
# ^source operand is immediate value

sub _impbin_temple_imm($dst,$src,$op) {

  # get size in bits
  my $alt   = bitsize($src);
  my $width = int_align(
    min($dst->{cap},$alt),8

  );

  # ^cap to word and extract
  $width=min($width,64);

  my @a=$dst->to_bytes($width);

  # ^apply passed fn
  $a[0]=$op->($a[0],$src);

  $dst->from_bytes(\@a,$width);

};

# ---   *   ---   *   ---
# ^bin or/xor

sub bor($reg,$any) {
  _impbin_temple($reg,$any,'|=');

};

sub bxor($reg,$any) {
  _impbin_temple($reg,$any,'^=');

};

# ---   *   ---   *   ---
# ^bin and/nand

sub band($reg,$any) {
  _impbin_temple($reg,$any,'&=');

};

sub bnand($reg,$any) {
  _impbin_temple($reg,$any,'&=~');

};

# ---   *   ---   *   ---
# shift left/right

sub bshl($reg,$any) {
  _impbin_temple($reg,$any,'<<=');

};

sub bshr($reg,$any) {
  _impbin_temple($reg,$any,'>>=');

};

# ---   *   ---   *   ---
1; # ret
