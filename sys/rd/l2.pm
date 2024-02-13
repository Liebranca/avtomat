#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:L2
# Branch sorter
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::l2;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# entry point

sub proc($class,$rd) {

  my @pending=@{$rd->{tree}->{leaves}};

  while(@pending) {

    my $nd=shift @pending;

    $rd->{branch}=$nd;

    $class->symbol($rd);
    $class->cslist($rd);
    $class->dopera($rd);


    unshift @pending,@{$nd->{leaves}};

  };

};

# ---   *   ---   *   ---
# template: run F for sequence

sub _seq_temple($fn,$branch,@seq) {

  my $have=0;

  while(defined (my $idex=$branch->match_sequence(
    @seq

  ))) {$have|=1;$fn->($idex)};


  return $have;

};

# ---   *   ---   *   ---
# identify token sequences
# matching [any] :: [any]

sub symbol($class,$rd) {

  state $re  = $rd->{l1}->tagre('\*',':');
  state @seq = ($ANY_MATCH,$re,$re,$ANY_MATCH);


  my $branch=$rd->{branch};

  # roll [any] :: [any]
  _seq_temple(sub ($idex) {

    my @lv=@{$branch->{leaves}};
       @lv=@lv[$idex..$idex+3];

    $lv[0]{value} .="\::$lv[3]->{value}";
    shift @lv;

    $branch->pluck(@lv);


  },$branch,@seq);

};

# ---   *   ---   *   ---
# identify comma-separated lists

sub cslist($class,$rd) {

  state $re  = $rd->{l1}->tagre('\*',',');
  state @seq = ($ANY_MATCH,$re,$ANY_MATCH);


  my $branch = $rd->{branch};

  my $cnt    = 0;
  my $pos    = -1;
  my $anchor = undef;


  # split at [any] , [any]
  _seq_temple(sub ($idex) {

    my @lv=@{$branch->{leaves}};
       @lv=@lv[$idex..$idex+2];

    ($anchor)=(! $anchor || $idex > $pos)

      ? $branch->insert(

          $idex,$rd->{l1}->make_tag(
            $rd,'IDEX'=>$cnt++

          )

        )

      : $anchor
      ;


    $lv[1]->discard();
    @lv=($lv[0],$lv[2]);

    shift @lv if $lv[0] eq $anchor;


    $anchor->pushlv(@lv);
    $pos=$idex;


  },$branch,@seq);


};

# ---   *   ---   *   ---
# join double operators

sub dopera($class,$rd) {

  state $left  = $rd->{l1}->tagre(
    '\*','['."\Q=<>!&|^-+*/".']'

  );

  state $right = $rd->{l1}->tagre(
    '\*','['."\Q=<>!&|^-+*/".']'

  );


  state @seq=($left,$right);


  my $branch = $rd->{branch};

  # split at [any] , [any]
  _seq_temple(sub ($idex) {

    my @lv=@{$branch->{leaves}};
       @lv=@lv[$idex..$idex+1];


    $lv[0]->{value}=$rd->{l1}->cat_tags(

      $rd,

      $lv[0]->{value},
      $lv[1]->{value},

    );

    $lv[1]->discard();


  },$branch,@seq);

};

# ---   *   ---   *   ---
1; # ret
