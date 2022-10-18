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

  my @pending=@{$tree->{leaves}};
  while(@pending) {

    my $branch=shift @pending;

# ---   *   ---   *   ---
# keyword without children

    if(

       ($branch->{value}=~ $self->{keyword_re})
    && !@{$branch->{leaves}}

    ) {

# ---   *   ---   *   ---
# ^root expression in keyword

      my @range=$tree->match_until(
        $branch,qr{;}x

      );

      shift @range;
      push @move,[$branch,@range];

      for(@range) {shift @pending};

# ---   *   ---   *   ---
# make "flat out" into single token

    } elsif(

       @{$branch->{leaves}}
    && $branch->{value} eq 'flat'
    && $branch->{leaves}->[0]->{value} eq 'out'

    ) {

      my $n=$branch->pluck(
        $branch->{leaves}->[0]

      );

      $branch->{value}.=' out';
      $branch->idextrav();

    };

# ---   *   ---   *   ---

  };

  for my $ref(@move) {

    my $anchor=shift @$ref;
    $anchor->pushlv(@$ref);

  };

  $rd->recurse($tree);
  $rd->replstr($tree);

# ---   *   ---   *   ---

  state $BEG_RE=qr{^\$\:VERT;>$}x;
  state $END_RE=qr{^\$\:FRAG;>$}x;

  my $v_beg=$tree->branch_in($BEG_RE);
  my @vert=$tree->match_until($v_beg,$END_RE);
  shift @vert;

  my $f_beg=$tree->branch_in($END_RE);
  my @frag=@{$tree->{leaves}};
  @frag=@frag[$f_beg->{idex}+1..$#frag];

  $v_beg->pushlv(@vert);
  $f_beg->pushlv(@frag);

  return ($v_beg,$f_beg);

};

# ---   *   ---   *   ---
1; # ret
