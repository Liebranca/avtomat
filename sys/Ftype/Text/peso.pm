#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO
# Sing swan song
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::peso;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys";
  use Arstd::Re qw(re_eiths);
  use Type::MAKE;

  use Ftype::Text;


# ---   *   ---   *   ---
# make ice

BEGIN { sub keyw_group(@ar) {
  return [re_eiths(\@ar,insens=>1,bwrap=>1)];

};Ftype::Text->new(

  name  => 'peso',

  ext   => '\.(pe|p3|rom)$',
  hed   => '[^A-Za-z0-9_]+[A-Za-z0-9_]*;',
  mag   => '$ program',

  type  => Type::MAKE->ALL_FLAGS,


  specifier=>keyw_group(qw(
    ptr fptr str buf tab re
    readable writeable executable
    virtual public static

  )),

  resname=>keyw_group(qw(
    self other null non
    stdin stdout stderr

  )),

  intrinsic=>keyw_group(qw(
    beq blk wed unwed ipol lis
    in out xform or xor and not neg
    cmp test defd

  )),

  directive=>keyw_group(qw(
    rom ram  exe reg clan proc
    entry atexit case  nocase
    macro def undef redef lib use

  )),

  fctl=>keyw_group(qw(
    jmp jz jnz jg jgz jl jlz
    call ret rept
    wait sys stop

  )),

  builtin=>keyw_group(qw(
    ld st lz lnz lg lgz ll llz
    pop push add sub inc dec exit

  )),

)};


# ---   *   ---   *   ---
1; # ret
