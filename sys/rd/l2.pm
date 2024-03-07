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
  use Arstd::IO;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.8;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $OPERA_UNARY => {
    map {$ARG=>1} qw(~ ? ! ++ --)

  };

  Readonly my $OPERA_BINARY => {

    map {$ARG=>1}
    qw  (+ - * / & ^ < > <= >= !)

  };

  Readonly my $OPERA_PRIO  => "&|^*/-+<>~?!=";

# ---   *   ---   *   ---
# cstruc

sub new($class,$rd) {

  return bless {
    rd     => $rd,
    walked => {},

  },$class;

};

# ---   *   ---   *   ---
# entry point
#
# sorts branches accto
# their structure

sub proc_parse($self) {

  my $rd=$self->{rd};

  # execution queue
  my @cmd = ();

  # get nodes of branch
  my @pending = (@{$rd->{nest}})

    ? $rd->{nest}->[-1]->{leaves}->[-1]

    : $rd->{tree}->{leaves}->[-1]

    ;

  # ^save current
  my $old  = $rd->{branch};
  my @recl = ();
  my $rec  = 0;

  # ^walk
  while(@pending) {


    # handle depth
    my $nd=shift @pending;
    if(! $nd) {
      $rec=0;
      next;

    };

    # join operators
    $rd->{branch}=$nd;
    $self->dopera();

    # go next
    push    @recl,[$nd,$rec];
    unshift @pending,@{$nd->{leaves}},0;

    $rec=1;

  };

  map {

    my ($nd,$rec)=@$ARG;

    # proc sub-branch
    $rd->{branch}=$nd;

    # sort operators
    $self->opera();


    # sort lists and sub-branches
    $self->cslist();
    $self->nested();


    # get head of branch is a command
    my $cmd = $self->cmd();
    my $l1  = $rd->{l1};

    # ^enqueue exec layer
    push @cmd,[@$cmd,$rec] if $cmd && $cmd ne 1;

  } reverse @recl;


  # run enqueued commands
  $self->exec_queue(@cmd);

  # restore starting branch
  $rd->{branch}=$old;

  return;

};

# ---   *   ---   *   ---
# go through [F,node,recurse] list
# and run F->(node)
#
# recurse field handles fetching
# of current execution state

sub exec_queue($self,@Q) {

  my $rd     = $self->{rd};
  my $lx     = $rd->{lx};

  my $walked = $self->{walked};


  $lx->exprbeg(0);

  map {


    # unpack
    my ($fn,$branch,$rec)=@$ARG;
    $rd->{branch}=$branch;

    $lx->exprbeg($rec);


    # check arguments and run
    rept:
      $lx->argchk();
      my $have=$fn->($lx,$branch);

    # ^branch was mutated by proc
    if($have && $have eq 'mut') {

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
# ~

sub proc_ctx($self,$nd,$Q) {

  my $rd=$self->{rd};

  if(exists $nd->{cmdkey}) {

    my $lx  = $rd->{lx};
    my $CMD = $lx->load_CMD();

    my $fn  = $CMD->{$nd->{cmdkey}}->{'ctx'};


    $fn->($lx,$nd) if defined $fn;

  };

};

# ---   *   ---   *   ---
# interpret node as a value

sub value_solve($self,$src=undef,$rec=0) {

  # default to current branch
  my $rd    = $self->{rd};
     $src //= $rd->{branch};

  # get ctx
  my $mc     = $rd->{mc};
  my $l1     = $rd->{l1};
  my $ptrcls = $mc->{bk}->{ptr};


  # output null if unsolved
  my $out=undef;

  # single token?
  if(! @{$src->{leaves}}) {

    $out=(! defined $l1->read_tag($src->{value}))
      ? $l1->symbol_fetch($src->{value})
      : $src->{value}
      ;

  # ^nope, recurse to solve tree
  } else {
    $out=$self->value_collapse($src);

  };


  return $out;

};

# ---   *   ---   *   ---
# ^interpret node *tree* as value

sub value_collapse($self,$src) {


  # get ctx
  my $rd     = $self->{rd};
  my $mc     = $rd->{mc};
  my $l1     = $rd->{l1};

  my $ptrcls = $mc->{bk}->{ptr};


  # recurse for each leaf
  my @lv   = @{$src->{leaves}};
  my @args = map {

    my $y=$self->value_solve($ARG,1);
    my $x=$l1->quantize($y);

    # make copy if X is ptr
    if($ptrcls->is_valid($x)) {
      $x=bless {%$x},$ptrcls;

    };

    (length $x) ? $x : () ;


  } @lv;


  # ^fail if we have unsolved leaves
  return null
  if int @lv != int @args;


  # ^else keep going
  my $out   = null;

  my $fn    = $src->{value};
  my @deref = map {

    # have ptr?
    if($ptrcls->is_valid($ARG)) {
      $ARG->{addr};

    # ^nope, plain value
    } else {$ARG};

  } @args;

  my $ptrdst=$ptrcls->is_valid($args[0]);


  # have operator?
  if(defined (my $opera=$l1->is_opera($fn))) {

    $deref[0]=eval {

      # [ARG]
      if($opera=~ qr{[\(\[\{]}) {

        if($opera eq '[' && $ptrdst) {
          $ptrdst=0;
          $args[0]->load();

        } else {
          $deref[0];

        };

      # [*ARG | ARG*]
      } elsif(exists $OPERA_UNARY->{$opera}) {

        my $s=($fn=~ qr{right$})
          ? "$opera$deref[0]"
          : "$deref[0]$opera"
          ;

        eval $s;

      # [ARG*ARG]
      } elsif(exists $OPERA_BINARY->{$opera}) {
        eval "$deref[0]$opera$deref[1]";

      };

    };


    # 'weird' operators not yet implemented ;>
    nyi "[`$opera]" if ! defined $out;


    # ~
    if($ptrdst) {
      $args[0]->{addr}=$deref[0];

    } else {
      $args[0]=$deref[0];

    };


    $out=$args[0];


  # have sub-branch?
  } elsif(defined (my $b=$l1->is_branch($fn))) {
    $out=$args[0];

  };


  # give token
  return $out;

};

# ---   *   ---   *   ---
# remove comments from branch

sub strip_comments($self,$src=undef) {


  # get ctx
  my $rd = $self->{rd};
  my $l1 = $rd->{l1};


  # default to current branch
  $src //= $rd->{branch};

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
  my $rd  = $self->{rd};
  my $l1  = $rd->{l1};

  # build/fetch regex sequence
  my $re  = $l1->tagre(OPERA=>',');
  my @seq = ($ANY_MATCH,$re,$ANY_MATCH);


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
  my $rd  = $self->{rd};
  my $l1  = $rd->{l1};

  # build/fetch regex sequence
  my $re=$l1->tagre(
    OPERA => '['."\Q$OPERA_PRIO".']'

  );

  my @seq    = ($re,$re);
  my $branch = $rd->{branch};


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
  my $rd  = $self->{rd};
  my $l1  = $rd->{l1};

  # build/fetch regex
  my $re=$l1->tagre(
    OPERA => '['."\Q$OPERA_PRIO".']+'

  );

  state $prio=[split $NULLSTR,$OPERA_PRIO];


  # get tagged operators in branch
  my $branch = $rd->{branch};
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

  $self->{rd}->{branch}->prich();

  $self->{rd}->perr(
    "no operands for `[op]:%s`",
    args=>[$char]

  );

};

# ---   *   ---   *   ---
# sorts nested branches

sub nested($self) {

  # get ctx
  my $rd  = $self->{rd};
  my $l1  = $rd->{l1};

  # build/fetch regex
  my $re=$l1->tagre(BRANCH=>'.+');


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

sub cmd($self) {

  # get ctx
  my $rd  = $self->{rd};
  my $l1  = $rd->{l1};
  my $lx  = $rd->{lx};

  my $key = lc $rd->{branch}->{value};
  my $CMD = $lx->load_CMD();

  # build/fetch regex
  my $re=$l1->tagre(CMD=>'.+');

  # have command?
  if($key=~ $re) {


    # get variation for current pass
    my ($type,$value)=$l1->read_tag($key);
    my $fn=$lx->stagef($value);


    # ^save key
    $rd->{branch}->{cmdkey}=$value;


    # consume argument nodes if need
    $lx->argsume($rd->{branch});


    # give F to run if any
    #
    # else just signal that the node
    # is a command!
    return (defined $fn)
      ? [$fn=>$rd->{branch}]
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
  my $rd = $self->{rd};
  my $l1 = $rd->{l1};

  # default to current
  $branch //= $rd->{branch};


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
