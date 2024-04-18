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
  use Arstd::Bytes;
  use Arstd::IO;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.0;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    main   => undef,
    branch => undef,

    walked => {},
    nest   => [],

    table  => {},

  },

  node_mutate => 'mut',

};


  Readonly my $OPERA_UNARY => {
    map {$ARG=>1} qw(~ ? ! ++ --)

  };

  Readonly my $OPERA_BINARY => {

    map {$ARG=>1}
    qw  (+ - * / & ^ < > <= >= !)

  };

  Readonly my $OPERA_PRIO  => "&|^*/-+<>~?!=";

# ---   *   ---   *   ---
# end current and begin new

sub term($self) {


  # get ctx
  my $main = $self->{main};
  my $l0   = $main->{l0};
  my $l1   = $main->{l1};


  # get deepest scope
  my $anchor   = $self->{nest}->[-1];
     $anchor //= $main->{tree};

  # ^get child count
  my $idex   = int @{$anchor->{leaves}};
     $idex   = $l1->tag(EXP=>$idex);

  # make new branch
  $self->{branch}=
    $self->cat($idex,$anchor);


  # mark beggining of expression
  $l0->flagset(exp=>0);
  return $self->{branch};

};

# ---   *   ---   *   ---
# push token to expression

sub cat($self,$value,$anchor=undef) {


  # get ctx
  my $main = $self->{main};
  my $l0   = $main->{l0};

  # defaults
  $anchor //= $self->{branch};
  $anchor //= $self->{nest}->[-1];

  # make new branch
  my $dst=$anchor->inew($value);

  # set misc branch attrs
  ( $dst->{lineno},
    $dst->{escaped}

  ) = (
    $main->{lineat},
    $l0->flagchk(esc=>1),

  );


  return $dst;

};

# ---   *   ---   *   ---
# open scope

sub enter($self,$src=undef) {

  # get ctx
  my $main  = $self->{main};
  my $dst   = $self->{nest};

  # default
  $src //= $self->{branch};
  $src //= $main->{tree};


  # make new anchor
  push @$dst,$src;
  return $self->term();

};

# ---   *   ---   *   ---
# ^undo

sub leave($self) {

  my $dst=$self->{nest};
  pop @$dst;

  $self->{branch}=($dst->[-1])
    ? $dst->[-1]->{leaves}->[-1]
    : undef
    ;

  return $self->{branch};

};

# ---   *   ---   *   ---
# clears empty expressions

sub sweep($self) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # find all expressions
  my $re=$l1->re(EXP=>'.*');
  my @lv=$main->{tree}->branches_in($re);

  # ^clear expressions without tokens!
  map  {$ARG->discard()}
  grep {! @{$ARG->{leaves}}} @lv;


  # reset own branch (in case we deleted it ;>)
  $self->{branch}=undef

  if ! $self->{branch}->{parent}

  &&   $self->{branch}
  ne   $main->{tree}
  ;

  return;

};

# ---   *   ---   *   ---
# add expression to table

sub define($self,$type,$name,@sig) {

  # get ctx
  my $main = $self->{main};
  my $tab  = $self->{table};
  my $l1   = $main->{l1};

  # ~
  my $dst  = 

  return;

};

# ---   *   ---   *   ---
# make [node=>recurse] array
# for a cannonical walk
#
# run method for each node

sub get_walk_array($self,$fn,@Q) {

  my @out  = ();

  my $main = $self->{main};
  my $rec  = 0;


  while(@Q) {


    # handle depth
    my $nd=shift @Q;

    if(! $nd) {
      $rec=0;
      next;

    };


    # run method for this node
    $main->{branch}=$nd;
    $fn->($self,$nd);

    # go next
    push    @out,[$nd,$rec];
    unshift @Q,@{$nd->{leaves}},0;

    $rec=1;

  };


  return @out;

};

# ---   *   ---   *   ---
# iter [node=>recurse] array
#
# run method for each node
# give back [node=>recurse]
# for each node that is a command

sub get_cmd_queue($self,$fn,@order) {

  my $main = $self->{main};
  my $l2   = $main->{l2};

  map {


    # get next
    my ($nd,$rec)=@$ARG;
    $main->{branch}=$nd;

    # run method for node
    $fn->($self,$nd);


    # get head of branch is a command
    # enqueue exec layer if so
    my $cmd=$l2->cmd();

    ($cmd && $cmd ne 1)
      ? [@$cmd,$rec]
      : ()
      ;


  } @order;

};

# ---   *   ---   *   ---
# post-parse bits
#
# 'fwd/rev' stand for the order
# in which the nodes are processed:
#
# * "fwd" is a cannonical walk
# * "rev" is bottom leaf to root

sub node_fwd_parse($self,$branch) {

  # join composite operators
  $self->dopera();

  # sort operators
  $self->opera();

  # join comma-separated lists
  $self->cslist();

  return;

};

sub node_rev_parse($self,$branch) {
  return;

};

# ---   *   ---   *   ---
# entry point
#
# sorts branches accto
# their structure

sub parse($self,$head=undef) {

  # get ctx
  my $main=$self->{main};

  # get head of branch?
  $head //= (@{$main->{nest}})
    ? $main->{nest}->[-1]->{leaves}->[-1]
    : $main->{tree}->{leaves}->[-1]
    ;

  # ^save current
  my $old=$main->{branch};

  # run and capture results
  my @out=$self->walk(

    $head,

    fwd=>\&node_fwd_parse,
    rev=>\&node_rev_parse,

  );


  # restore and give
  $main->{branch}=$old;

  return @out;

};

# ---   *   ---   *   ---
# generic iter-through of
# an array of nodes

sub walk($self,$branch,%O) {

  # defaults
  $O{fwd}  //= $NOOP;
  $O{rev}  //= $NOOP;
  $O{self} //= $self;


  # get walk order
  my @order=get_walk_array(
    $O{self},$O{fwd},$branch

  );

  # ^get execution queue
  my @cmd=get_cmd_queue(
    $O{self},$O{rev},reverse @order

  );


  # ^run and capture results
  return $self->exec_queue(@cmd);


};

# ---   *   ---   *   ---
# ^a walk within a walk!

sub recurse($self,$branch,%O) {

  my $old=$self->{main}->{$branch};
  my @out=$self->walk($branch,%O);

  $self->{main}->{branch}=$old;


  return @out;

};

# ---   *   ---   *   ---
# go through [F,node,recurse] list
# and run F->(node)
#
# recurse field handles fetching
# of current execution state

sub exec_queue($self,@Q) {

  my $main   = $self->{main};
  my $lx     = $main->{lx};

  my $walked = $self->{walked};


  $lx->exprbeg(0);

  map {


    # out
    my $have=undef;

    # unpack
    my ($cmd,$branch,$rec)=@$ARG;
    $lx->exprbeg($rec);

    # top node forcing un-reversal?
    if(my @unrev=$lx->bunrev($branch)) {
      $walked->{$branch->{-uid}}--;
      goto skip;

    };


    # validate and run
    rept:

      $main->{branch}=$branch;
      $cmd->argchk();

      $have=$cmd->{fn}->($cmd,$branch);


    # ^branch was mutated by proc
    if($have && $have eq $self->node_mutate()) {

      # have new command?
      my $mut=$self->cmd();

      # ^replace and repeat if so
      if($mut && $mut ne 1) {
        ($cmd,$branch)=@$mut;
        goto rept;

      };

    };


    # save and give result if defined
    skip:
      $lx->exprlink($have);


  # avoid processing the same node twice
  } grep {
    $walked->{$ARG->[1]->{-uid}}//=0;
  ! $walked->{$ARG->[1]->{-uid}}++

  } @Q;


};

# ---   *   ---   *   ---
# remove comments from branch

sub strip_comments($self,$src=undef) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # default to current branch
  $src //= $main->{branch};

  # ^walk
  my @pending=$src;
  while(@pending) {

    my $nd=shift @pending;

    if(defined $l1->is_comment($nd->{value})) {
      $nd->discard();

    } else {
      unshift @pending,@{$nd->{leaves}};

    };

  };


  return;

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
# identify comma-separated lists

sub cslist($self) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # build/fetch regex sequence
  my $re  = $l1->re(OPR=>',');
  my @seq = ($ANY_MATCH,$re,$ANY_MATCH);


  my $branch = $main->{branch};

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
          $idex,$l1->tag(LIST=>$cnt++)

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

sub dopera($self) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # build/fetch regex sequence
  my $re=$l1->re(
    OPR => '['."\Q$OPERA_PRIO".']'

  );

  my @seq    = ($re,$re);
  my $branch = $main->{branch};

  my @reset  = ();

  _seq_temple(sub ($idex) {


    my @lv=@{$branch->{leaves}};
       @lv=@lv[$idex..$idex+1];

    # join both operators into first
    if(! @{$lv[0]->{leaves}}) {
      $lv[0]->{value}=$l1->cat_tags(
        $lv[0]->{value},
        $lv[1]->{value},

      );

      # ^remove second
      $lv[1]->discard();


    # false positive!
    } else {

      push @reset,[
        $lv[0]->{value},
        $lv[0]->{idex}

      ];

      $lv[0]->{value}=null;

    };


  },$branch,@seq);


  # ^restore false positives
  map {
    my ($value,$idex)=@$ARG;
    $branch->{leaves}->[$idex]->{value}=$value;

  } @reset;


  return;

};

# ---   *   ---   *   ---
# make sub-branch from
# [token] opera [token]

sub opera($self) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # build/fetch regex
  my $re=$l1->re(
    OPR => '['."\Q$OPERA_PRIO".']+'

  );

  state $prio=[split $NULLSTR,$OPERA_PRIO];


  # get tagged operators in branch
  my $branch = $main->{branch};
  my @ops    = map {

    # get characters/priority for this operator
    my $char = $l1->typechk(
        OPR=>$ARG->{value}

    )->{spec};

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


    # edge case:
    #
    #   if lh is first token in expression,
    #   it is the parent node!

    if($rh && $rh eq $lh) {
      $lh=$par->inew($par->{value});
      $par->repl($ARG);

    };


    # have unary operator?
    if($OPERA_UNARY->{$char}) {

      $self->throw_no_operands($char)
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

      $self->throw_no_operands($char)
      if ! defined $rh ||! defined $lh;

      $ARG->pushlv($lh,$rh);

    };

  } @ops;

};

# ---   *   ---   *   ---
# ^errme

sub throw_no_operands($self,$char) {

  $self->{main}->{branch}->prich();

  $self->{main}->perr(
    "no operands for `[op]:%s`",
    args=>[$char]

  );

};

# ---   *   ---   *   ---
# solve command tags

sub cmd($self) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $lx   = $main->{lx};

  my $key = lc $main->{branch}->{value};
  my $tab = $lx->load_CMD();

  # build/fetch regex
  my $re=$l1->re(CMD=>'.+');

  # have command?
  if($key=~ $re) {


    # get definition for current stage
    my ($type,$value)=$l1->read_tag($key);
    my $cmd=$tab->fetch($value);

    # ^validate
    if(! length $cmd) {

      $main->{branch}->prich(errout=>1);

      $main->perr(
        "undefined command: '%s'",
        args=>[$value],

      );

    };


    # ^save key
    $main->{branch}->{cmdkey}=$value;


    # consume argument nodes if need
    $cmd->argsume($main->{branch})
    if $cmd && exists $main->{strterm};


    # give F to run if any
    #
    # else just signal that the node
    # is a command!
    return (defined $cmd)
      ? [$cmd=>$main->{branch}]
      : 1
      ;

  };


  return 0;

};

# ---   *   ---   *   ---
# get node is the first
# token in an expression

sub is_exprtop($self,$branch=undef) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # default to current
  $branch //= $main->{branch};


  # is grandparent root?
  my $par  = $branch->{parent};
  my $gpar = $par->{parent};

  return 1 if ! defined $gpar->{parent};


  # is parent the beggining of a branch?
  my $idex = $l1->is_branch($par->{node});
  return 1 if defined $idex;


  # ^nope, you're not at the top!
  return 0;

};

# ---   *   ---   *   ---
1; # ret
