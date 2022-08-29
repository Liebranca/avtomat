#!/usr/bin/perl
# ---   *   ---   *   ---
# flat assembler

# ---   *   ---   *   ---

# deps
package Lang::fasm;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;
  use Arstd;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use parent 'Lang::Def';

# ---   *   ---   *   ---
# adds to cache

  use Vault 'ARPATH';

# ---   *   ---   *   ---
# ROM

  my $OPS=Lang::quick_op_prec(

    '*'=>7,
    '->'=>4,
    '.'=>6,

  );

# ---   *   ---   *   ---

BEGIN {

my $NUMS=$Lang::Def::DEFAULTS{nums};
$NUMS->{'(\$[0-9A-F]+)'}=\&Lang::pehexnc;

Lang::fasm->nit(

  name=>'fasm',

  ext=>'\.fa$',
  mag=>'^flat assembler file',
  com=>';',

  op_prec=>$OPS,
  exp_bound=>"\n",
  nums=>$NUMS,

# ---   *   ---   *   ---

  types=>[qw(

    db file rb
    du dw rw
    dd dp df rd rp rf
    dq dt rq rt

  )],

  specifiers=>[qw(

    byte word dword fword pword
    qword tbyte tword dqword xword
    qqword yword dqqword zword

    ptr

    readable writeable executable
    public extrn

    local

  )],

# ---   *   ---   *   ---

  intrinsics=>[qw(

    dup and or xor shl shr
    bsf bsr not rva plt cmp equ

  )],

  directives=>[qw(
    label format section segment
    rept repeat struc macro loop

    irp irps match

    common forward reverse

    if else end
    load store at from

    include fix define
    display err

  )],

  fctls=>[qw(

    @[@rb]

    jmp near far short

    call syscall
    enter leave

    ret

  )],

  builtins=>[qw(

    mov mod adc add sbb sub push pop imul
    inc jl jg je jne

    ror rol

  )],

# ---   *   ---   *   ---

  resnames=>[qw(

    al cl dl bl ah ch dh bh
    bpl dil

    ax cx dx bx sp bp si di

    eax ecx edx ebx esp ebp esi edi
    rax rcx rdx rbx rsp rbp rsi rdi

    r8 r9 r10 r11 r12 r13 r14 r15

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

# ---   *   ---   *   ---

)};
