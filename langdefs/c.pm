#!/usr/bin/perl
# ---   *   ---   *   ---
# C syntax defs

# ---   *   ---   *   ---

# deps
package langdefs::c;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
  use langdefs::plps;

# ---   *   ---   *   ---

use constant OPS=>lang::quick_op_prec(

  '*'=>7,
  '->'=>4,
  '.'=>6,

);

# ---   *   ---   *   ---

BEGIN {
lang::def::nit(

  -NAME=>'c',

  -EXT=>'\.([ch](pp|xx)?|C|cc|c\+\+|cu|H|hh|ii?)$',
  -MAG=>'^(C|C\+\+) (source|program)',
  -COM=>'//',

  -OP_PREC=>OPS,

# ---   *   ---   *   ---

  -TYPES=>[qw(

    bool char short int long
    float double void

    int8_t int16_t int32_t int64_t
    uint8_t uint16_t uint32_t uint64_t

    wchar_t size_t

    FILE

    nihil stark signal

  )],

  -SPECIFIERS=>[qw(

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

  -INTRINSICS=>[qw(

    sizeof offsetof typeof alignof
    typename alignas

    static_assert cassert
    _Generic __attribute__

    new delete

  )],

  -DIRECTIVES=>[qw(
    class struct union typedef enum

  )],

  -FCTLS=>[qw(

    if else for while do
    switch case default
    try throw catch break
    continue goto return

  )],

# ---   *   ---   *   ---

  -RESNAMES=>[qw(
    this

  )],

# ---   *   ---   *   ---

  -PREPROC=>[
    lang::delim2('#',"\n"),

  ],

  -MCUT_TAGS=>[-STRING,-CHAR,-PREPROC],

# ---   *   ---   *   ---

  -EXP_RULE=>sub ($) {

    my $rd=shift;

    my $preproc=\lang::CUT_TOKEN_RE;
    $preproc=~ s/\[A-Z\]\+/PREPROC[A-Z]/;

    while($rd->{-LINE}=~ s/^(${preproc})//) {
      push @{$rd->exps},{body=>$1,has_eb=>0};

    };

  },

# ---   *   ---   *   ---

  -MLS_RULE=>sub ($$) {

    my ($self,$s)=@_;

    if($s=~ m/(#\s*if)/) {

      my $open=$1;
      my $close=$open;

      $close=~ s/(#\s*)//;
      $close=$1.'endif';

      $self->del_mt->{$open}=$close;

      return "($open)";

# ---   *   ---   *   ---

    } elsif($s=~ m/(#\s*define\s+)/) {

      my $open=$1;
      my $close="\n";

      $self->del_mt->{$open}=$close;

      return "($open)";

    } else {return undef;};

  },

# ---   *   ---   *   ---
# build language patterns

);lang->c->{-PLPS}=langdefs::plps::make(lang->c);

};

# ---   *   ---   *   ---
1; # ret
