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

  use List::Util qw(min max);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::Re;

  use Mach::Seg;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $INS=>[qw(

    cpy     mov
    wap     clr

    push    pop
    alloc

    bor     bxor
    band    bnand
    bshl    bshr

    mod

    xorkey  rev
    jmp

  )];

# ---   *   ---   *   ---
# adds instructions to table

sub engrave($class,$frame) {

  no strict 'refs';
  my $ins=${"$class\::INS"};

  state $lissed=re_eiths([qw(
    push pop

  )]);

  map {

    my %O=();

    if($ARG=~ $lissed) {
      $O{lis}=$ARG;
      $ARG="_$ARG";

    };

    $frame->add($ARG,%O,pkg=>$class);

  } @$ins;

};

# ---   *   ---   *   ---
# copy seg or imm to reg

sub cpy($reg,$any) {

  my $type=(Mach::Seg->is_valid($any))
    ? 'seg'
    : 'num'
    ;

  $reg->set($type=>$any);

  return 0;

};

# ---   *   ---   *   ---
# ^reg to reg, clears src operand

sub mov($reg0,$reg1) {
  $reg0->set(seg=>$reg1);
  $reg1->set(num=>0x00);

  return 0;

};

# ---   *   ---   *   ---
# ^swap them out

sub wap($reg0,$reg1) {

  my $tmp=${$reg0->{buf}};

  $reg0->set(seg  => $reg1);
  $reg1->set(rstr => $tmp);

  return 0;

};

# ---   *   ---   *   ---
# ^clear

sub clr($mach,$any) {
  my $dst=$mach->decode_ptr($any);
  $dst->set(num=>0x00);

  return 0;

};

# ---   *   ---   *   ---
# reset executable segment

sub jmp($mach,$any) {

  my $pos=(Mach::Seg->is_valid($any))
    ? ($any->get())[0]
    : $any
    ;

  return $mach->xs_branch($pos);

};

# ---   *   ---   *   ---
# stack control

sub _push($mach,$any) {
  $mach->stkpush($any);
  return 0;

};

sub _pop($mach,$reg) {
  my $x=$mach->stkpop();
  $reg->set(num=>$x);

  return 0;

};

# ---   *   ---   *   ---
# request memory

sub alloc($reg_a,$reg_b,$imm) {

  my $frame  = $reg_a->{frame};
  my $mach   = $frame->{-mach};

  my $name   = $reg_b->get_str();

  $reg_a->set(ptr=>$mach->new_seg($name,$imm));

  return 0;

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

    q[%=]  => sub {$_[0] %  $_[1]},

  };

  $op=$tab->{$op};

  if(Mach::Seg->is_valid($src)) {
    _impbin_temple_seg($dst,$src,$op);

  } else {
    _impbin_temple_imm($dst,$src,$op);

  };

  return 0;

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
  my $width = int_align($dst->{cap}*8,8);

  # ^cap to word and extract
  $width=min($width,64);

  my @a=$dst->to_bytes($width);

  # ^apply passed fn
  @a=map {$op->($ARG,$src)} @a;

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
# ^shift left/right

sub bshl($reg,$any) {
  _impbin_temple($reg,$any,'<<=');

};

sub bshr($reg,$any) {
  _impbin_temple($reg,$any,'>>=');

};

# ---   *   ---   *   ---
# ^inplace modulo

sub mod($reg,$any) {
  _impbin_temple($reg,$any,'%=');

};

# ---   *   ---   *   ---
# generates key by xoring
# words of value together
#
# saves result to first operand
#
# see: bitter/tests/xortile

sub xorkey($reg,$seg) {

  my $out=0;

  my @bytes=$seg->to_bytes(
    min(64,$seg->{cap}*8)

  );

  map {$out^=$ARG} @bytes;

  $reg->set(num=>$out);

  return 0;

};

# ---   *   ---   *   ---
# byte-wise invert register
#
# out-stretches the definition
# of "doing little" ;>

sub rev($reg) {

  my $width = min(64,$reg->{cap}*8);
  my @bytes = $reg->to_bytes($width);

  # ^walk elems
  @bytes=map {

    my $x    = $ARG;

    my $i    = 0;
    my $word = 0;

    my @back = ();

    # save head
    map {
      push @back,($x >> $ARG) & 0xFF

    } (0,8,16,24);

    # ^iv with tail
    map {

      my $y=($x >> $ARG) & 0xFF;
      my $n=shift @back;

      $word |= ($y << $i) | ($n << $ARG);

      $i+=8;

    } (56,48,40,32);

    $word;

  } @bytes;

  $reg->from_bytes(\@bytes,$width);

  return 0;

};

# ---   *   ---   *   ---
1; # ret
