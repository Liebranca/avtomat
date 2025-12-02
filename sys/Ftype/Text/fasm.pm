#!/usr/bin/perl
# ---   *   ---   *   ---
# fasm
# no caps
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::fasm;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Arstd::Re;
  use parent 'Ftype::Text';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v1.00.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# make ice

sub classattr {return {
  name      => 'fasm',
  ext       => '\.(s|asm|inc)$',
  mag       => '^flat assembler file',

  com       => ';',
  lcom      => Arstd::Re::eaf(';',lbeg=>0,opscape=>0),

  types=>[qw(
    db file rb
    du dw rw
    dd dp df rd rp rf
    dq dt rq rt
  )],

  specifier=>[qw(
    byte word dword fword pword
    qword tbyte tword dqword xword
    qqword yword dqqword zword

    readable writeable executable
    public extrn

    label local virtual public
  )],

  intrinsic=>[qw(
    dup and or xor shl shr
    bsf bsr not rva plt cmp equ eq

    used relativeto in eqtype ptr
    at from as nop

    lis
  )],

  directive=>[qw(
    format section segment
    rept repeat struc macro loop

    purge restruc restore assert

    heap stack neg

    irp irps match

    common forward reverse

    if else end while break
    load store org

    include fix define defined definite
    display err align times

    postpone
    lib use

    strucdef capture
  )],

  fctl=>[qw(
    @[@rb]

    jmp near far short
    jn?[lgez]e?

    call syscall
    enter leave

    ret
  )],

  builtin=>[qw(
    c?movn?[lgez]e? mod adc add
    sbb sub push pop imul mul div
    inc dec str lea

    ror rol
  )],


  # registers <3
  resname=>[qw(
    rax eax ax ah al
    rcx ecx cx ch cl
    rdx edx dx dh dl
    rbx ebx bx bh bl
    rsp esp sp spl
    rbp ebp bp bpl
    rsi esi si sil
    rdi edi di dil

    r8 r8d r8w r8b
    r9 r9d r9w r9b

    r10 r10d r10w r10b
    r11 r11d r11w r11b
    r12 r12d r12w r12b
    r13 r13d r13w r13b
    r14 r14d r14w r14b
    r15 r15d r15w r15b

    es cs ss ds fs gs

    cr0 cr2 cr3 cr4
    dr0 dr1 dr2 dr3 dr6 dr7

    st0 st1 st2 st3 st4 st5 st6 st7
    mm0 mm1 mm2 mm3 mm4 mm5 mm6 mm7

    xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7
    ymm0 ymm1 ymm2 ymm3 ymm4 ymm5 ymm6 ymm7
    zmm0 zmm1 zmm2 zmm3 zmm4 zmm5 zmm6 zmm7

    k0 k1 k2 k3 k4 k5 k6 k7
    bnd0 bnd1 bnd2 bnd3

    %t
  )],

}};


# ---   *   ---   *   ---
1; # ret
