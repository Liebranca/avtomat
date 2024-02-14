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
  use Arstd::Array;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $OPERA_UNARY => {
    map {$ARG=>1} qw(~ ? ! ++ --)

  };

  Readonly my $OPERA_PRIO  => "&|^*/-+.:<>~?!=";

# ---   *   ---   *   ---
# entry point

sub proc($class,$rd) {


  # get nodes of branch
  my @cmd     = ();
  my @pending = (@{$rd->{nest}})

    ? $rd->{nest}->[-1]->{leaves}->[-1]

    : $rd->{tree}->{leaves}->[-1]

    ;

  # save current
  my $old=$rd->{branch};


  # ^walk
  while(@pending) {

    my $nd=shift @pending;

    # proc sub-branch
    $rd->{branch}=$nd;

    # sort operators
    $class->dopera($rd);
    $class->opera($rd);

    # join [token] :: [token]
    $class->symbol($rd);

    # sort lists and sub-branches
    $class->cslist($rd);
    $class->nested($rd);


    # enqueue exec layer and go next
    push    @cmd,$class->cmd($rd);
    unshift @pending,@{$nd->{leaves}};

  };


  # commands in queue?
  state $walked={};

  map {

    my ($fn,$branch)=@$ARG;

    $rd->{branch}=$branch;
    $rd->{lx}->argchk($rd);

    $fn->($rd,$branch);


  # avoid processing the same node twice
  } grep {
      $walked->{$ARG->[1]}//=0;
    ! $walked->{$ARG->[1]}++

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
    $rd,OPERA => '['."\Q$OPERA_PRIO".']'

  );

  state $right = $rd->{l1}->tagre(
    $rd,OPERA => '['."\Q$OPERA_PRIO".']'

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
# make sub-branch from
# [token] opera [token]

sub opera($class,$rd) {

  state $re=$rd->{l1}->tagre(
    $rd,OPERA => '['."\Q$OPERA_PRIO".']+'

  );

  state $prio=[split $NULLSTR,$OPERA_PRIO];


  # get tagged operators in branch
  my $branch = $rd->{branch};
  my @ops    = map {

    # get characters/priority for this operator
    my $char = $rd->{l1}->read_tag_v(
        $rd,OPERA=>$ARG->{value}

    );

    my $idex = array_iof(
      $prio,(substr $char,-1,1)

    );

    # ^record
    $ARG->{opera_char}=$char;
    $ARG->{opera_prio}=$idex;

    $ARG;

  # ^that havent been already handled ;>
  } grep {
    ! exists $ARG->{opera_prio}

  } $branch->branches_in($re);

  # leave if no operators found!
  return if ! @ops;


  # sort operators by priority... manually
  #
  # builtin sort can't handle this
  # for some reason
  my @sops=();

  map {
    $sops[$ARG->{opera_prio}] //= [];
    push @{$sops[$ARG->{opera_prio}]},$ARG;

  } @ops;

  # ^flatten sorted array of arrays!
  @ops=map {@$ARG} grep {$ARG} @sops;


  # restruc the tree
  map {

    my $char = $ARG->{opera_char};
    my $idex = $ARG->{idex};

    my $par  = $ARG->{parent};
    my $rh   = $par->{leaves}->[$idex+1];
    my $lh   = $par->{leaves}->[$idex-1];


    # have unary operator?
    if($OPERA_UNARY->{$char}) {

      throw_no_operands($rd,$char)
      if ! defined $rh &&! defined $lh;

      # assume ++X
      if(defined $rh) {
        $ARG->pushlv($rh);
        $ARG->{value}.='right';

      # ^else X++
      } else {
        $ARG->pushlv($lh);
        $ARG->{value}.='left';

      };


    # ^nope, good times
    } else {

      throw_no_operands($rd,$char)
      if ! defined $rh ||! defined $lh;

      $ARG->pushlv($lh,$rh);

    };

  } @ops;

};

# ---   *   ---   *   ---
# ^errme

sub throw_no_operands($rd,$char) {

$rd->{branch}->prich();

  $rd->perr(
    "no operands for `[op]:%s`",
    args=>[$char]

  );

};

# ---   *   ---   *   ---
# sorts nested branches

sub nested($class,$rd) {

  state $re=$rd->{l1}->tagre(
    $rd,BRANCH=>'.+'

  );


  my $branch = $rd->{branch};
  my @left   = ();

  # split at [any] , [any]
  _seq_temple(sub ($idex) {

    my $par    = $branch->{leaves}->[$idex];
    my $anchor = $par->{leaves}->[0];

    my @have   = $par->all_from($anchor);

    $anchor->pushlv(@have);


    push @left,[$idex=>$branch->pluck($par)];


  },$branch,$re);


  map {
    my ($idex,$sbranch)=@$ARG;
    $branch->insertlv($idex,$sbranch);

  } reverse @left;


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

    if(defined $fn) {
      $rd->{branch}->{cmdkey}=$value;
      return [$fn=>$rd->{branch}];

    };

  };


  return ();

};

# ---   *   ---   *   ---
1; # ret
