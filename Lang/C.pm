#!/usr/bin/perl
# ---   *   ---   *   ---
# C syntax defs

# ---   *   ---   *   ---

# deps
package Lang::C;

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

  Readonly my $OPS=>Lang::quick_op_prec(

    '*'=>7,
    '->'=>4,
    '.'=>6,

  );

# ---   *   ---   *   ---

BEGIN {
Lang::C->nit(

  name=>'C',

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

  preproc=>Shwl::delm('#',"\n"),

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

)};

sub hier_sort($self,$rd) {

  my $block=$rd->select_block(-ROOT);
  my $tree=$block->{tree};

  my $re=qr{

    ^(?: $self->{fn_key}
     |   $self->{utype_key}

    )$

  }x;

# ---   *   ---   *   ---

  for my $sbl($tree->branches_in($re)) {
    if(!@{$sbl->{leaves}}) {

      my $idex=$sbl->{idex};

# ---   *   ---   *   ---

      my $ahead=$sbl->{parent}
        ->{leaves}->[$idex+1];

      if(defined $ahead) {
        $sbl->pushlv(
          $sbl->{parent}->pluck($ahead)

        );

      };

# ---   *   ---   *   ---

    };

  };

};

# ---   *   ---   *   ---
1; # ret
