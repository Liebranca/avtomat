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

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# entry point

sub proc($class,$rd) {


  # get nodes of branch
  my @cmd     = ();
  my @pending = $rd->{tree}->{leaves}->[-1];
  my $old     = $rd->{branch};


  # ^walk
  while(@pending) {

    my $nd=shift @pending;

    # proc sub-branch
    $rd->{branch}=$nd;

    $class->dopera($rd);
    $class->symbol($rd);
    $class->cslist($rd);


    # enqueue exec layer and go next
    push    @cmd,$class->cmd($rd);
    unshift @pending,@{$nd->{leaves}};

  };


  # commands in queue?
  map {
    my ($fn,$branch)=@$ARG;
    $fn->($rd,$branch);

  } reverse @cmd;


  # restore starting branch
  $rd->{branch}=$old;

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

  state $re  = $rd->{l1}->tagre($rd,OPERA=>'::');
  state @seq = ($ANY_MATCH,$re,$ANY_MATCH);


  my $branch=$rd->{branch};

  # roll [any] :: [any]
  _seq_temple(sub ($idex) {

    my @lv=@{$branch->{leaves}};
       @lv=@lv[$idex..$idex+2];

    # cat next to first
    $lv[0]{value} .="\::$lv[2]->{value}";

    # drop first and discard the rest
    shift @lv;
    $branch->pluck(@lv);


  },$branch,@seq);

};

# ---   *   ---   *   ---
# identify comma-separated lists

sub cslist($class,$rd) {

  state $re  = $rd->{l1}->tagre($rd,OPERA=>',');
  state @seq = ($ANY_MATCH,$re,$ANY_MATCH);


  my $branch = $rd->{branch};

  my $cnt    = 0;
  my $pos    = -1;
  my $anchor = undef;


  # split at [any] , [any]
  _seq_temple(sub ($idex) {

    my @lv=@{$branch->{leaves}};
       @lv=@lv[$idex..$idex+2];

    # have [list] COMMA [value]?
    ($anchor)=(! $anchor || $idex > $pos)

      # make new list
      ? $branch->insert(

          $idex,$rd->{l1}->make_tag(
            $rd,'IDEX'=>$cnt++

          )

        )

      # ^else cat to existing
      : $anchor
      ;


    # remove the comma
    $lv[1]->discard();
    @lv=($lv[0],$lv[2]);

    # ^drop the list if catting to existing
    shift @lv if $lv[0] eq $anchor;

    # ^add nodes to list
    $anchor->pushlv(@lv);
    $pos=$idex;


  },$branch,@seq);


};

# ---   *   ---   *   ---
# join double operators

sub dopera($class,$rd) {

  state $left  = $rd->{l1}->tagre(
    $rd,OPERA => '['."\Q=<>!&|^-+*/.:".']'

  );

  state $right = $rd->{l1}->tagre(
    $rd,OPERA => '['."\Q=<>!&|^-+*/.:".']'

  );


  state @seq=($left,$right);


  my $branch = $rd->{branch};

  # split at [any] , [any]
  _seq_temple(sub ($idex) {

    my @lv=@{$branch->{leaves}};
       @lv=@lv[$idex..$idex+1];

    # join both operators into first
    $lv[0]->{value}=$rd->{l1}->cat_tags(

      $rd,

      $lv[0]->{value},
      $lv[1]->{value},

    );

    # ^remove second
    $lv[1]->discard();


  },$branch,@seq);

};

# ---   *   ---   *   ---
# solve command tags

sub cmd($class,$rd) {

  state $re=$rd->{l1}->tagre($rd,CMD=>'.+');

  my $key=$rd->{branch}->{value};
  my $CMD=$rd->{lx}->load_CMD();

  if($key=~ $re) {

    my ($type,$value)=
      $rd->{l1}->read_tag($rd,$key);

    my $pass = $rd->{lx}->passname($rd);
    my $fn   = $CMD->{$value}->{$pass};

    return [$fn=>$rd->{branch}] if defined $fn;

  };


  return ();

};

# ---   *   ---   *   ---
1; # ret
