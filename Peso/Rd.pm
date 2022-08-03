#!/usr/bin/perl
# ---   *   ---   *   ---
# RD
# PLPS-capable parser frontend
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Peso::Rd;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;
  use Arstd;
  use Chk;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;
  use Peso::Ex;

# ---   *   ---   *   ---
# info

  our $VERSION=v2.50.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,$ex,$fname,%opts) {

  my $rd=bless {

    ex=>$ex,
    lang=>$ex->{lang},

    blocks=>Shwl::codefold(
      $fname,$ex->{lang},%opts

    ),

    curblk=>undef,
    fname=>$fname,

  },$class;

  return $rd;

};

# ---   *   ---   *   ---
# strips comments and blanks

sub cleaner($self,$body) {

  my $comment_re=$self->{lang}->{strip_re};
  $body=~ s/($comment_re)//sgmx;

  if(!length stripline($body)) {
    $body=$NULLSTR;

  };

  return $body;

};

# ---   *   ---   *   ---
# branches out node from token

sub tokenizer($self,$body,$root=undef) {

  my $exp_bound_re=$self->{lang}->{exp_bound_re};
  my @exps=();

# ---   *   ---   *   ---
# filter out empties

  { my @tmp=split $exp_bound_re,$body;

    for my $s(@tmp) {
      if(

         defined $s
      && length stripline($s)

      ) {
        push @exps,$s;

      };

    };

  };

# ---   *   ---   *   ---
# only attempt tokenization when
# there is more than one possible token!
# ... or if the single token is valid code ;>

  if( (@exps==1)
  &&  ($exps[0]=~ $exp_bound_re)

  ) {goto TAIL};

# ---   *   ---   *   ---
# convert the string into a tree branch

  my $nd_frame=$self->{ex}->{node};
  for my $exp(@exps) {

    $exp=$nd_frame->nit($root,$exp);
    $exp->tokenize();

    if(!defined $root) {
      $root=$exp;

    };

  };

# ---   *   ---   *   ---

TAIL:
  return $root;

};

# ---   *   ---   *   ---
# executes expandable tokens across
# the given tree branch

sub recurse($self,@pending) {

  my $block=$self->{curblk};
  my $cut_a_re=$self->{lang}->{cut_a_re};

# ---   *   ---   *   ---
# walk the hierarchy

  while(@pending) {
    my $node=shift @pending;

# ---   *   ---   *   ---
# check node for expandable tokens

TOP:

    my $key=$node->{value};
    if($key=~ m/($cut_a_re)/) {

      $key=${^CAPTURE[0]};

      # replace token with code string
      my $repl=$block->{strings}->{$key};
      $node->{value}=~ s/${key}/$repl/;

      my $body=$self->cleaner($node->{value});
      my $new_branch=$self->tokenizer($body);

# ---   *   ---   *   ---
# multiple expansions, consume root

      if(@{$new_branch->{leaves}}) {

        $node->repl($new_branch);
        $node=$new_branch;

        unshift @pending,$node,@{$node->{leaves}};
        $node->flatten_branch(keep_root=>1);

# ---   *   ---   *   ---
# single expansion, consume childless branch

      } else {

        $node->{value}=$new_branch->{value};

        unshift @pending,@{$node->{leaves}};
        $node->flatten_branch(keep_root=>1);

        goto TOP;

      };

# ---   *   ---   *   ---
# nothing to expand

    } else {
      unshift @pending,@{$node->{leaves}};

    };

  };

};

# ---   *   ---   *   ---

sub parse($lang,$fname,%opts) {

  my $m=Peso::Program->nit($lang);
  my $self=Peso::Rd->nit($m,$fname,%opts);

# ---   *   ---   *   ---
# make tree from block data

  my $nd_frame=$m->{node};
  for my $id(keys %{$self->{blocks}}) {

    my $root=$nd_frame->nit(undef,$id);
    my $block=$self->{blocks}->{$id};

    my $body=$self->cleaner($block->{body});

    $self->tokenizer($body,$root);

    $block->{tree}=$root;

  };

# ---   *   ---   *   ---
# pluck ending comment if present

  my $root=$self->{blocks}
    ->{-ROOT}->{tree};

  my $top=$root->{leaves}->[-1];

  if($top->{value}=~ $m->{lang}->{strip_re}) {
    $root->pluck($top);

  };

  return $self;

};

# ---   *   ---   *   ---
# set current block from id

sub select_block($self,$id) {

  $self->{curblk}=$self->{blocks}->{$id};
  return $self->{curblk};

};

# ---   *   ---   *   ---
# eliminates whitespace around ops

sub tighten_ops($self,$ref) {

  my $op=$self->{lang}->{ops};
  $$ref=~ s/\s*($op)\s*/$1/;

};

# ---   *   ---   *   ---

sub group_lists($self,$tree) {

  my $separator=$self->{lang}->{sep_ops};

  my $in_list=0;
  my $prev=undef;

  my @list=();
  my @result=();
  my @discard=();

# ---   *   ---   *   ---

  for my $leaf(@{$tree->{leaves}}) {

    if($leaf->{value}=~ $separator) {

      if(!@list) {
        push @list,$prev;

      };

      push @discard,$leaf;
      $in_list=1;

# ---   *   ---   *   ---

    } elsif($in_list) {

      push @list,$leaf;
      $in_list=0;

    } else {

      if(@list) {
        push @result,[@list];

      };

      @list=();

    };

# ---   *   ---   *   ---

    $prev=$leaf;

  };

# ---   *   ---   *   ---

  if(@list) {
    push @result,[@list];

  };

  for my $ref(@result) {

    my $idex=$ref->[0]->{idex};
    $tree->insert(
      $idex,'list:'

    );

    my $list=$tree->{leaves}->[$idex];
    $list->pushlv(@$ref,overwrite=>1);

  };

  $tree->pluck(@discard);

};

# ---   *   ---   *   ---
# expands tokens into string literals

sub replstr($self,$root) {

  my $block=$self->{curblk};
  my $cut_b_re=$self->{lang}->{cut_b_re};

  for my $branch($root->branches_in($cut_b_re)) {

    my $key=$branch->{value};
    if($key=~ m/($cut_b_re)/) {

      $key=${^CAPTURE[0]};

      # replace token with raw string
      my $repl=$block->{strings}->{$key};
      $branch->{value}=~ s/${key}/$repl/;

    };

  };

};

# ---   *   ---   *   ---

sub find_args($self) {

# NOTE: though this works for most languages,
#       we should really take this re from
#       a langdef...

  state $parens_re=qr{^\s*\(\s*|\s*\)\s*$}x;
  state $comma_re=qr{\s*,\s*}x;

# ---   *   ---   *   ---

  my $block=$self->{curblk};
  my $branch=$block->{tree};

  my @out=();
  my @args=();

  if(length $block->{args}) {

    my $args=$block->{args};

    $args=~ s/$parens_re//sg;
    @args=split m/$comma_re/,$args;

  };

# ---   *   ---   *   ---

  my $args_re=qr{$^};
  if(@args) {

    @args=map {Shwl::Arg->nit($ARG)} @args;

    $args_re=Lang::arrpat(
      [map {$ARG->{name}} @args],0,1

    );

    @out=$branch->branches_in($args_re);

  };

  return $args_re,\@args,@out;

};

# ---   *   ---   *   ---
# find assignment

sub find_asg_ops($self,@branches) {

  my %asg=();
  my $asg_op=$self->{lang}->{asg_op};

  for my $branch(@branches) {

    if(exists $asg{$branch->{value}}) {
      my $ar=$asg{$branch->{value}};
      push @$ar,$branch;

    };

# ---   *   ---   *   ---

    my $match;
    if(!@{$branch->{leaves}}) {
      $match=$branch->{parent}
        ->branch_in($asg_op);

    } else {
      $match=$branch->branch_in($asg_op);

    };

# ---   *   ---   *   ---

    if(defined $match) {
      $asg{$branch->{value}}=[$branch];

    };

# ---   *   ---   *   ---


  };

  return %asg;

};

# ---   *   ---   *   ---
# fills out hashref with functions in tree

sub fn_search($self,$tree,$h,$typecon) {

  my $lang=$self->{lang};
  my $fn_key=qr{^$lang->{fn_key}$};

# ---   *   ---   *   ---
# iter through functions

  for my $fn($tree->branches_in($fn_key)) {

    my $id=$fn->leaf_value(0);
    my $src=$self->select_block($id);

    my $attrs=$src->{attrs};
    my $name=$src->{name};
    my $args=$src->{args};

    my $type=$typecon->($attrs);

    my $fn=$h->{$name}={

      type=>$type,
      args=>{},

    };

# ---   *   ---   *   ---
# save args

    $args=~ s/$lang->{strip_re}//sg;
    $args=~ s/^\s*\(|\)\s*$//sg;

    my @args=split $COMMA_RE,$args;

    while(@args) {

      my $arg=shift @args;
      $arg=~ s/^\s+|\s+$//;

      my ($arg_attrs,$arg_name)=
        split $SPACE_RE,$arg;

      # is void
      if(!defined $arg_name) {
        $arg_name=$NULLSTR;

      };

      my $arg_type=$typecon->($arg_attrs);

      $fn->{args}->{$arg_name}=$arg_type;

# ---   *   ---   *   ---

    };

  };

};

# ---   *   ---   *   ---
# fills out hashref with user-defined
# types in tree

sub utype_search($self,$tree,$h,$typecon) {

  my $lang=$self->{lang};
  my $utype_key=qr{^$lang->{utype_key}$};

  my $re=qr{[^;]+}x;

# ---   *   ---   *   ---
# iter through functions

  for my $utype($tree->branches_in($utype_key)) {

    my $id=$utype->leaf_value(0);

    my $src=$self->select_block(
      $Shwl::UTYPE_PREFIX.$id

    );

    $h->{$id}={};

# ---   *   ---   *   ---
# iter struct fields

    my $nd=$src->{tree};
    for my $field($nd->branches_in(

      $re,

      max_depth=>0,
      keep_root=>0,

    )) {

#:!;> this assumes C rules and NO specifiers!

      my $type=$typecon->($field->{value});
      my $name=$field->leaf_value(0);

      $h->{$id}->{$name}=$type;

    };

  };

};

# ---   *   ---   *   ---
1; # ret
