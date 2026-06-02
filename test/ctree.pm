#!/usr/bin/perl
# ---   *   ---   *   ---

package tests::ctree;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys";
  use Tree::C;


# ---   *   ---   *   ---
# ~~

my $cstr=q[
macro test {
  my ($nd)=@_;
  use PM Arstd::fatdump;
  fatdump \$nd;
  return ();
};

test;

];

my $tree = Tree::C->rd($cstr);
my @expr = $tree->to_expr();

say $tree->expr_to_code(@expr);


# ---   *   ---   *   ---
1; # ret
