#!/usr/bin/perl
# ---   *   ---   *   ---
# Rust syntax defs

# ---   *   ---   *   ---

# deps
package Lang::Rust;

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
Lang::Rust->nit(

  name=>'Rust',

  ext=>'\.(rlib|rs)$',
  mag=>'^Rust (source|program)',
  com=>'//',

  op_prec=>$OPS,

# ---   *   ---   *   ---

  types=>[qw(

    i8 i16 i32 i64 i128 isize
    u8 u16 u32 u64 u128 usize

    f32 f64

    bool char

  )],

  specifiers=>[qw(

    let mut static virtual priv pub
    extern abstract const

  )],

# ---   *   ---   *   ---

  intrinsics=>[qw(

    typeof in as

  )],

  directives=>[qw(
    class struct union typedef enum
    loop macro match fn use

    become box crate dyn
    final impl mod move
    override ref trait type unsafe unsized

  )],

  fctls=>[qw(

    async await

    if else for while do
    match try break where
    continue return

    yield

  )],

# ---   *   ---   *   ---

  resnames=>[qw(
    this true false self super

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

# ---   *   ---   *   ---
1; # ret
