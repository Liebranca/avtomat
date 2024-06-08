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
  use Arstd::PM;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    main   => undef,
    branch => undef,

    walked => {},
    nest   => [],

    tab    => {},

  },

  node_mutate => 'mut',
  sigtab_t    => 'rd::sigtab',

};

# ---   *   ---   *   ---
# module kick

sub build($self) {


  # get ctx
  my $main  = $self->{main};
  my $l1    = $main->{l1};

  # load helper modules
  my $class=$self->sigtab_t;

  cloadi $class;
  cloadi $class->sig_t;


  # nit sequence tables
  my $tab=$self->{tab}={
    'fwd-parse'=>$class->new($main),

  };


  return;

};

# ---   *   ---   *   ---
# get definitions subtable

sub get_stab($self,$type) {

  # get ctx
  my $main = $self->{main};
  my $stab = $self->{tab}->{$type};

  # validate and give
  $main->perr(
    "invalid [ctl]:%s type: '%s'",
    args=>[invoke=>$type],

  ) if ! defined $stab;


  return $stab;

};

# ---   *   ---   *   ---
# find and execute sequences

sub invoke($self,$type,@name) {


  # get subtable and backup state
  my $main = $self->{main};
  my $stab = $self->get_stab($type);
  my $old  = $self->{branch};

  # validate input
  my @list=map {$stab->valid_fetch($ARG)} @name;


  # find and solve patterns
  my $exclude={};

  while(my @have=$stab->find(

    $old,

    list    => \@list,
    exclude => $exclude,

  )) {

    # ^walk matches and call attached method
    for my $packed(@have) {

      my ($keyw,$data,$nd)=@$packed;

      $self->{branch}=$nd;

      my $out=$keyw->{fn}->(
        $main->{syntax},$nd,$data

      );

      $exclude->{$nd->{-uid}}=1
      if $out eq '-x';

    };

  };


  # restore and give
  $self->{branch}=$old;
  return;

};

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
  ne   $main->{tree};

  return;

};

# ---   *   ---   *   ---
# add expression to table

sub define($self,$type,$name,%O) {


  # defaults
  $O{re}   //= null;
  $O{fn}   //= $NOOP;
  $O{sig}  //= [];
  $O{flat} //= 0;

  # get ctx
  my $main = $self->{main};
  my $stab = $self->get_stab($type);
  my $l1   = $main->{l1};


  # make new keyword
  $stab->begin($name);

  # add arguments signature if need
  my @sig=@{$O{sig}};

  $stab->pattern(@sig)
  if @sig;

  # ^same deal for function and regex!
  $stab->function($O{fn})
  if $O{fn} ne $NOOP;

  $stab->regex($O{re})
  if length $O{re};


  # set sequence match rules
  $stab->set_flat($O{flat});


  # write to table and give
  $stab->build();

  return $stab->{$name};

};

# ---   *   ---   *   ---
# make [node=>recurse] array
# for a cannonical walk
#
# run method for each node

sub get_walk_array($self,$fn,@Q) {

  my @out  = ();
  my $main = $self->{main};


  while(@Q) {


    # handle depth
    my $nd=shift @Q;
    next if! $nd;


    # run method for this node
    $self->{branch}=$nd;
    $fn->($self,$nd);

    # go next
    push    @out,$nd;
    unshift @Q,@{$nd->{leaves}},0;

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
    my $nd=$ARG;
    $l2->{branch}=$nd;


    # run method for node
    $fn->($self,$nd);


    # get head of branch is a command
    # enqueue exec layer if so
    my $cmd=$l2->cmd();

    ($cmd && $cmd ne 1)
      ? [@$cmd]
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

  my $main = $self->{main};
  my $syx  = $main->{syntax};

  $syx->apply_rules($branch);

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
  my $old=$self->{branch};

  # run and capture results
  my @out=$self->walk(

    $head,

    fwd=>\&node_fwd_parse,
    rev=>\&node_rev_parse,

  );


  # restore and give
  $self->{branch}=$old;

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

  my $old=$self->{branch};
  my @out=$self->walk($branch,%O);

  $self->{branch}=$old;


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


  map {


    # out
    my $have=undef;

    # unpack
    my ($cmd,$branch)=@$ARG;

    # top node forcing un-reversal?
    if(my @unrev=$lx->bunrev($branch)) {
      $walked->{$branch->{-uid}}--;
      goto skip;

    };


    # validate and run
    rept:

      $self->{branch}=$branch;
      $have=$cmd->{key}->{fn}->($cmd,$branch);


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


    # give result if defined
    (defined $have) ? $have : () ;


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
  $src //= $self->{branch};

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
# solve command tags

sub cmd($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $lx   = $main->{lx};

  my $key = lc $self->{branch}->{value};
  my $tab = $lx->load_CMD();

  # build/fetch regex
  my $re=$l1->re(CMD=>'.+');


  # have command?
  if($key=~ $re) {


    # get definition for current stage
    my ($have) = $l1->untag($key);
    my $value  = $have->{spec};

    my $cmd=$tab->fetch($value);


    # ^validate
    if(! length $cmd) {

      $self->{branch}->prich(errout=>1);

      $main->perr(
        "undefined command: '%s'",
        args=>[$value],

      );

    };


    # consume argument nodes if need
    $cmd->argsume($self->{branch})

    if  exists $main->{buf}
    &&! $self->{branch}->{cmdkey};


    $self->{branch}->{cmdkey}=$value;

    return [$cmd=>$self->{branch}];

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
  $branch //= $self->{branch};


  # is grandparent root?
  my $par  = $branch->{parent};
  my $gpar = $par->{parent};

  return 1 if ! defined $gpar->{parent};


  # is parent the beggining of a branch?
  return 1 if $l1->typechk(EXP=>$par->{value});


  # ^nope, you're not at the top!
  return 0;

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {
  my @out=rd::layer::mint($self);
  return @out,tab => $self->{tab};

};

# ---   *   ---   *   ---
1; # ret
