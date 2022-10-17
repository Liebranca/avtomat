#!/usr/bin/perl
# ---   *   ---   *   ---
# syntax defs for sin preprocessor

# ---   *   ---   *   ---

# deps
package Lang::SinGL;

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
Lang::SinGL->nit(

  name=>'SinGL',

  ext=>'\.(sg|glsl)$',
  mag=>'^SIN_SHADER',
  com=>'//',

  op_prec=>$OPS,

# ---   *   ---   *   ---

  types=>[qw(

    void bool int uint float

    [biu]?vec[234]
    mat[234]

    sampler([^\s]+)?
    buffer

  )],

  specifiers=>[qw(

    const uniform in out flat

  )],

# ---   *   ---   *   ---

  intrinsics=>[qw()],

  directives=>[qw(
    struct union layout

  )],

  fctls=>[qw(

    if else for while do
    switch case default
    break continue return

  )],

# ---   *   ---   *   ---

  resnames=>[qw()],

# ---   *   ---   *   ---

  preproc=>Shwl::delm('#',"\n"),

  foldtags=>[qw(
    chars strings preproc pesc

  )],

# ---   *   ---   *   ---

)};

sub hier_sort($self,$rd) {

  my $blk=$rd->select_block(-ROOT);
  my $tree=$blk->{tree};

  my @move=();
  $tree->idextrav();

  my @pending=@{$tree->{leaves}};

  while(@pending) {

    my $branch=shift @pending;

    if(

       ($branch->{value}=~ $self->{keyword_re})
    && !@{$branch->{leaves}}

    ) {

      my @range=$tree->match_until(
        $branch,qr{;}x

      );

      shift @range;
      push @move,[$branch,@range];

      for(@range) {shift @pending};

    };

  };

# ---   *   ---   *   ---

  for my $ref(@move) {

    my $anchor=shift @$ref;
    $anchor->pushlv(@$ref);

  };

};

# ---   *   ---   *   ---
1; # ret
