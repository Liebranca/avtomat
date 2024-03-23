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

  our $VERSION = v0.01.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {
    main   => undef,
    walked => {},

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

  my $main=$self->{main};

  map {


    # get next
    my ($nd,$rec)=@$ARG;
    $main->{branch}=$nd;

    # run method for node
    $fn->($self,$nd);


    # get head of branch is a command
    # enqueue exec layer if so
    my $cmd=$self->cmd();

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

};

sub node_rev_parse($self,$branch) {

  # sort operators
  $self->opera();

  # sort lists and sub-branches
  $self->cslist();
  $self->nested();

};

# ---   *   ---   *   ---
# entry point
#
# sorts branches accto
# their structure

sub parse($self) {

  # get ctx
  my $main=$self->{main};

  # get head of branch
  my $head=(@{$main->{nest}})
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
# ^generic walk

sub walk($self,$branch,%O) {

  # defaults
  $O{fwd} //= $NOOP;
  $O{rev} //= $NOOP;


  # get walk order
  my @order=$self->get_walk_array(
    $O{fwd},$branch

  );

  # ^get execution queue
  my @cmd=$self->get_cmd_queue(
    $O{rev},reverse @order

  );

  # ^run and capture results
  return $self->exec_queue(@cmd);


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


    # unpack
    my ($fn,$branch,$rec)=@$ARG;
    $lx->exprbeg($rec);


    # validate and run
    rept:

      $main->{branch}=$branch;
      $lx->argchk() if ! $main->{stage};

      my $have=$fn->($lx,$branch);


    # ^branch was mutated by proc
    if($have && $have eq $self->node_mutate()) {

      # have new command?
      my $cmd=$self->cmd();

      # ^replace and repeat if so
      if($cmd && $cmd ne 1) {
        ($fn,$branch)=@$cmd;
        goto rept;

      };

    };


    # save and give result if defined
    $lx->exprlink($have);


  # avoid processing the same node twice
  } grep {
    $walked->{$ARG->[1]}//=0;
  ! $walked->{$ARG->[1]}++

  } @Q;

};

# ---   *   ---   *   ---
# interpret node as a value

sub value_solve($self,$src=undef,$rec=0) {


  # default to current branch
  my $main   = $self->{main};
     $src  //= $main->{branch};

  # get ctx
  my $mc     = $main->{mc};
  my $l1     = $main->{l1};
  my $ptrcls = $mc->{bk}->{ptr};


  # output null if unsolved
  my $out=undef;

  # single token?
  if(! @{$src->{leaves}}) {
    $out=$l1->quantize($src->{value});

  # ^nope, analyze tree
  } else {
    $out=$self->branch_collapse($src);

  };


  return $out;

};

# ---   *   ---   *   ---
# default leaf-to-root
# branch processing logic

sub branch_solve($self,$branch) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # have operator?
  my $key=$branch->{value};

  if(defined (my $have=$l1->is_opera($key))) {

    my $dst=($have ne '(')
      ? $self->opera_collapse($branch,$have)
      : $branch->leaf_value(0)
      ;

    $branch->{value}=$dst;
    $branch->clear();


  # 'branch' token denotes any {[(code)]}
  # between delimiters
  } elsif(defined ($have=$l1->is_branch($key))) {

    $self->sbranch_collapse(
      $branch,$have

    );

  };


  return;


};

# ---   *   ---   *   ---
# ^recursive

sub branch_collapse($self,$src) {


  # save current state
  my $main = $self->{main};
  my $mc   = $main->{mc};

  $mc->{anima}->backup();


  # get reverse hierarchal order
  my @Q0 = @{$src->{leaves}};
  my @Q1 = ($src);

  while(@Q0) {

    my $nd=shift @Q0;

    push    @Q1,$nd;
    unshift @Q0,@{$nd->{leaves}};

  };


  # ^collapse from bottom leaf to root
  map {$self->branch_solve($ARG)}
  reverse @Q1;


  # cleanup and give
  $mc->{anima}->restore();
  return $src->{value};

};

# ---   *   ---   *   ---
# ^on sub-branch token

sub sbranch_collapse($self,$branch,$id) {

  my $par = $branch->{parent};
  my @lv  = @{$branch->{leaves}};


  if(1 == @lv) {
    $branch->flatten_branch();

  };


  return;

};

# ---   *   ---   *   ---
# execute const operator branch
# else give handle to executable

sub opera_collapse($self,$branch,$opera) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};
  my $imp  = $ISA->imp();

  # save current state
  my $alma = $mc->{anima}->{almask};


  #  get argument types
  my @args   = $branch->branch_values();
  my @args_b = map {

    my ($type,$spec) = $l1->read_tag($ARG);
    my $have         = $l1->quantize($ARG);

    $type .= $spec if $type eq 'm';
    (defined $have) ? [$type,$have] : () ;


  } @args;


  # ^validate
  return null
  if @args_b != int @args;

  @args=@args_b;


  # branch is a constant if it in turn
  # operates solely on constants!
  my $const=1;

  # apply formatting to arguments
  @args=map {

    my ($type,$have)=@$ARG;

    if($type eq 'r') {
      $const &=~ 1;
      {type=>$type,reg=>$have};

    } elsif($type eq 'i') {
      my $spec=(8 < bitsize $have) ? 'y' : 'x' ;
      {type=>"i$spec",imm=>$have};

    } else {
      nyi "memory operands";

    };


  } @args;


  # fetch operator definition
  my @program=$ISA->xlate(
    $opera,'word',@args

  );


  # give plain value on const branch
  if($const) {


    # build and unpack the opcodes
    @program=map {
      my ($opcd)=$ISA->encode(@$ARG);
      $ISA->decode($opcd);

    } @program;

    # ^execute and give result
    my $x=$mc->ipret(@program);
    $mc->{anima}->{almask}=$alma;

    return $l1->make_tag(NUM=>$x);


  # ^make mini-executable for non-const!
  } else {

    # make new segment holding opcodes
    my $seg=$mc->{scratch}->new();
    $mc->exewrite($seg,@program);

    # ^give handle via id
    return $l1->make_tag(EXE=>$seg->{iced});

  };

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
  my $re  = $l1->tagre(OPERA=>',');
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
          $idex,$l1->make_tag('LIST'=>$cnt++)

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
  my $re=$l1->tagre(
    OPERA => '['."\Q$OPERA_PRIO".']'

  );

  my @seq    = ($re,$re);
  my $branch = $main->{branch};


  _seq_temple(sub ($idex) {


    my @lv=@{$branch->{leaves}};
       @lv=@lv[$idex..$idex+1];

    # join both operators into first
    $lv[0]->{value}=$l1->cat_tags(
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

sub opera($self) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # build/fetch regex
  my $re=$l1->tagre(
    OPERA => '['."\Q$OPERA_PRIO".']+'

  );

  state $prio=[split $NULLSTR,$OPERA_PRIO];


  # get tagged operators in branch
  my $branch = $main->{branch};
  my @ops    = map {

    # get characters/priority for this operator
    my $char = $l1->read_tag_v(
        OPERA=>$ARG->{value}

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
# sorts nested branches

sub nested($self) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # build/fetch regex
  my $re=$l1->tagre(BRANCH=>'.+');


  my $branch = $main->{branch};
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

sub cmd($self) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $lx   = $main->{lx};

  my $key = lc $main->{branch}->{value};
  my $CMD = $lx->load_CMD();

  # build/fetch regex
  my $re=$l1->tagre(CMD=>'.+');

  # have command?
  if($key=~ $re) {


    # get variation for current pass
    my ($type,$value)=$l1->read_tag($key);
    my $fn=$lx->stagef($value);

    # ^save key
    $main->{branch}->{cmdkey}=$value;


    # consume argument nodes if need
    $lx->argsume($main->{branch})
    if ! $main->{stage};


    # give F to run if any
    #
    # else just signal that the node
    # is a command!
    return (defined $fn)
      ? [$fn=>$main->{branch}]
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
