#!/usr/bin/perl
# ---   *   ---   *   ---
# C syntax defs

# ---   *   ---   *   ---

# deps
package langdefs::c;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
#  use langdefs::plps;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use shwl;

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

  preproc=>shwl::delm('#',"\n"),

  foldtags=>[qw(
    chars strings preproc

  )],

# ---   *   ---   *   ---

  fn_key=>q{function},
  fn_decl=>q{

    (?<attrs>

      (?: $:specifiers->re;>\s+)*
      $:types->re;>

      \s*\**\s*

    )\s*

    (?<name> $:names;>)

    \s*(?<args> \([\S\s]*?\))\s*

    (?<scope> [{]

      (?<code> [^{}] | (?&scope))*

    [}] | (;))

  },

# ---   *   ---   *   ---

  utype_key=>q{struct},

  utype_decl=>q{

    (?:typedef\s+)?
    $:utype_key;>\s+

    (?<name> $:names;>\s+)?

    (?<scope> [{]

      (?<code> [^{}] | (?&scope))*

    [}])\s*

    (?<name> $:names;>\s*)? ;?

  },

# ---   *   ---   *   ---
# build language patterns

);##lang->c->{_plps}=langdefs::plps::make(lang->c);

lang->c->{hier_sort}=sub($rd) {

  my $block=$rd->select_block(-ROOT);
  my $tree=$block->{tree};

  my $lang=$rd->{lang};

  my $re=qr{

    ^(?: $lang->{fn_key}
     |   $lang->{utype_key}

    )$

  }x;

  for my $sbl($tree->branches_in($re)) {
    if(!@{$sbl->{leaves}}) {

      my $idex=$sbl->{idex};

# ---   *   ---   *   ---

      my $ahead=$sbl->{parent}
        ->{leaves}->[$idex+1];

      if(defined $ahead) {
        $sbl->pushlv(0,
          $sbl->{parent}->pluck($ahead)

        );

      };

# ---   *   ---   *   ---

    };

#    my $id=$sbl->leaf_value(0);
#    if($sbl->{value} eq $lang->{utype_key}) {
#      $id=$shwl::UTYPE_PREFIX.$id;
#
#      $block=$rd->select_block($id);
#      $block->{tree}->prich();
#
#    };

  };

};

# ---   *   ---   *   ---

};

# ---   *   ---   *   ---
1; # ret
