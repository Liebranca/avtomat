#!/usr/bin/perl
# ---   *   ---   *   ---
# C syntax defs

# ---   *   ---   *   ---

# deps
package langdefs::c;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
#  use langdefs::plps;

# ---   *   ---   *   ---
# ROM

  Readonly my $OPS=>lang::quick_op_prec(

    '*'=>7,
    '->'=>4,
    '.'=>6,

  );

# ---   *   ---   *   ---

BEGIN {
lang::def::nit(

  name=>'c',

  ext=>'\.([ch](pp|xx)?|C|cc|c\+\+|cu|H|hh|ii?)$',
  mag=>'^(C|C\+\+) (source|program)',
  com=>'//',

  op_prec=>$OPS,

# ---   *   ---   *   ---

  types=>[qw(

    bool char short int long
    float double void

    int8_t int16_t int32_t int64_t
    uint8_t uint16_t uint32_t uint64_t

    wchar_t size_t

    FILE

    nihil stark signal

  )],

  specifiers=>[qw(

    auto extern inline restrict
    const signed unsigned static

    explicit friend mutable
    namespace override private
    protected public register

    template using virtual volatile
    noreturn _Atomic complex imaginary
    thread_local operator

  )],

# ---   *   ---   *   ---

  intrinsics=>[qw(

    sizeof offsetof typeof alignof
    typename alignas

    static_assert cassert
    _Generic __attribute__

    new delete

  )],

  directives=>[qw(
    class struct union typedef enum

  )],

  fctls=>[qw(

    if else for while do
    switch case default
    try throw catch break
    continue goto return

  )],

# ---   *   ---   *   ---

  resnames=>[qw(
    this

  )],

# ---   *   ---   *   ---

  preproc=>[
    lang::delim2('#',"\n"),

  ],

  foldtags=>[qw(
    chars strings preproc

  )],

# ---   *   ---   *   ---
# build language patterns

);##lang->c->{_plps}=langdefs::plps::make(lang->c);

};

# ---   *   ---   *   ---
1; # ret
