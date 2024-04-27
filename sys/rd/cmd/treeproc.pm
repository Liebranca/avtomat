#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:CMD TREEPROC
# Wrestles with branches
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmd::treeproc;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# subdivide command body into blocks

sub branch_subdiv($self,$branch,@expr) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};


  # last match inclusive?
  my $inc=do {

    my $elem = pop @expr;
    my $have = ($elem=~ s[^\&][])
      ? $elem
      : null
      ;

    push @expr,$elem;

    $have;

  };


  # re to find block types
  my $re=$l1->tagre(
    CMD=>join '|',@expr

  );


  # ^walk
  my @block = $branch->branches_in($re);
  my $idex  = 0;

  map {


    # get first && next match
    my $beg = $ARG->{parent};
    my $end = $block[++$idex]->{parent};


    # parent found nodes to block
    #
    # IF it's a middle block,
    # OR the last block is inclusive!

    if($ARG->{value} ne $inc) {


      # get nodes in between
      my @have=(defined $end)


        # all nodes from (beg,end)?
        ? $branch->match_until_other(
          $beg,$end,inclusive=>0

        )

        # ^all nodes after beg!
        : $branch->all_from($beg)
        ;


      # parent sub-branch to beg!
      $ARG->pushlv(@have);

    };


  } @block[0..$#block];


  return;

};

# ---   *   ---   *   ---
# template: collapse list in
# reverse hierarchical order

sub rcollapse_list($self,$branch,$fn) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};


  # first token, first command
  my $have = $l1->xlate($branch->{value});
  my @list = $have->{spec};
  my $par  = $branch->{parent};

  # ^get tokens from previous iterations
  push @list,@{$branch->{vref}}
  if exists $branch->{vref};

  $branch->{vref} = \@list;


  # parent is command, keep collapsing
  my $head = $l1->xlate($par->{value});
  if(defined $head && $head->{type} eq 'CMD') {

    # save commands to parent, they'll be
    # picked up in the next run of this F
    $par->{vref} //= [];
    push @{$par->{vref}},@list;

    # ^remove this token
    $branch->flatten_branch();


    return;


  # ^stop at last node in the chain
  } else {
    $fn->();

  };

};

# ---   *   ---   *   ---
1; # ret
