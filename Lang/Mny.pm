#!/usr/bin/perl
# ---   *   ---   *   ---
# project management stuff

# ---   *   ---   *   ---

# deps
package Lang::Mny;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use parent 'Lang::Def';

# ---   *   ---   *   ---

BEGIN {
Lang::Mny->new(

  name=>'Mny',
  ext=>'\.mny$',
  hed=>'\$mny;',

  mag=>'\$:get0x24;>',

  exp_bound=>qr"(?<! \\)\n"x,
  strip_re=>qr{\#.+\n},

# ---   *   ---   *   ---

  highlight=>[

    'f:([^[:blank:]]+/[^[:blank:]]+)+'=>0x04,
    '[/:.]'=>0x0F,

    '^>+.+$'=>0x83,
    '^\*>.+$'=>0x8E,
    '^~'=>0x01,
    '^x'=>0x02,

  ],

);
};

# ---   *   ---   *   ---

sub hier_sort($self,$rd) {

  my $block=$rd->select_block(-ROOT);
  my $tree=$block->{tree};

  $rd->recurse($tree);

# ---   *   ---   *   ---

  my @targets=$tree->branches_in(qr{^>+});

  for my $i(0..$#targets) {

    my @block=
      $tree->leaves_between($i,$i+1,@targets);

    my $branch=$targets[$i];

    $branch->pushlv(@block);
    $tree->idextrav();

  };

# ---   *   ---   *   ---

  my @tasks=();

  for my $target(@targets) {

    my @items=$target->branches_in(qr{^\*>});

    for my $i(0..$#items) {

      my @block=
        $target->leaves_between($i,$i+1,@items);

      my $branch=$items[$i];

      $branch->pushlv(@block);
      $target->idextrav();

      push @tasks,$branch;

    };

  };

# ---   *   ---   *   ---

  for my $task(@tasks) {

    my @moved=$task->branches_in(qr{

      ^(?:x|~) \s* [\^]+

    }x);

    map {$ARG->{lvl}=0} @{$task->{leaves}};
    my $max_lvl=0;

    for my $m(@moved) {
      $m->{value}=~ s{([\^]+)\s*}{};
      $m->{lvl}=length $1;

      $max_lvl=$m->{lvl} if $m->{lvl} > $max_lvl;

    };

# ---   *   ---   *   ---
# handle branching tasks
# this works like so:
#
#   Task
#   ^  branch_0 (parents to 'Task')
#   ^^ branch_1 (parents to 'branch_0')
#   ^  branch_2 (parents to 'Task')
#
# you may use as many ^^^^ hats as you like
# to deeply nest branches.

    while($max_lvl) {

      # get nodes at bottom
      my @tabbed=grep {
        $ARG->{lvl} eq $max_lvl

      } @{$task->{leaves}};

      $max_lvl--;

      # get nodes at top
      my @leaves=grep {
        $ARG->{lvl} eq $max_lvl

      } @{$task->{leaves}};

# ---   *   ---   *   ---
# parent bottom nodes to nearest top one

      for my $tab(@tabbed) {

        my $bot=$tab->{idex};
        my $top=0;

        map {

          my $i=$ARG->{idex};
          $top=$i if $i > $top && $i < $bot;

        } @leaves;

        $task->{leaves}->[$top]->pushlv($tab);

      };

# ---   *   ---   *   ---

    };

  };

};

# ---   *   ---   *   ---
1; # ret
