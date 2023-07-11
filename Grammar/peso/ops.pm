#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO OPS
# Funky expressions
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::ops;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::IO;
  use Arstd::PM;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;

  use Grammar;
  use Grammar::peso::common;
  use Grammar::peso::value;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_OPS);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # inherits from
  submerge(
    [qw(Grammar::peso::value)],
    xdeps=>1,

  );

# ---   *   ---   *   ---
# class attrs

  sub Frame_Vars($class) { return {
    %{$PE_COMMON->Frame_Vars()},

  }};

  Readonly our $PE_OPS=>
    'Grammar::peso::ops';

# ---   *   ---   *   ---
# op => F
# precedence given by array idex

  Readonly our $OPERATORS=>[

    q[->*] => 'm_call',
    q[->]  => 'm_attr',

    q[*^]  => 'pow',
    q[*]   => 'mul',
    q[%]   => 'mod',
    q[/]   => 'div',

    q[+]   => 'add',
    q[-]   => 'sub',

    q[<<]  => 'lshift',
    q[>>]  => 'rshift',

    q[&]   => 'b_and',
    q[|]   => 'b_or',
    q[^]   => 'b_xor',
    q[~]   => 'b_not',

    q[!]   => 'not',

    q[<]   => 'lt',
    q[<=]  => 'e_lt',
    q[>]   => 'gt',
    q[>=]  => 'e_gt',

    q[&&]  => 'and',
    q[||]  => 'or',
    q[^^]  => 'xor',

    q[~=]  => 'match',
    q[==]  => 'eq',
    q[!=]  => 'ne',

  ];

  Readonly our $OPHASH=>{@$OPERATORS};
  Readonly our $OP_KEYS=>[array_keys($OPERATORS)];

# ---   *   ---   *   ---
# ^makes note of unary ops

  Readonly our $OP_UNARY=>{
    q[!]=>1,
    q[~]=>1,

  };

# ---   *   ---   *   ---
# ^makes note of ops taking slurp args

  Readonly our $OP_SLURP=>{
    q[->*] => 1,
    q[->]  => 1,

  };

# ---   *   ---   *   ---
# ^makes note of ops requiring ctx access

  Readonly our $OP_CTX=>{
    q[~=] => 1,

  };

# ---   *   ---   *   ---
# call member F/getset member var

sub op_m_call($lhs,$rhs,@args) {};
sub op_m_attr($lhs,$rhs,@args) {};

# ---   *   ---   *   ---
# math

sub op_pow($lhs,$rhs) {return $lhs ** $rhs};

sub op_mul($lhs,$rhs) {return $lhs * $rhs};
sub op_mod($lhs,$rhs) {return $lhs % $rhs};
sub op_div($lhs,$rhs) {return $lhs / $rhs};
sub op_add($lhs,$rhs) {return $lhs + $rhs};
sub op_sub($lhs,$rhs) {return $lhs - $rhs};

# ---   *   ---   *   ---
# bits

sub op_lshift($lhs,$rhs) {return $lhs << $rhs};
sub op_rshift($lhs,$rhs) {return $lhs >> $rhs};

sub op_b_and($lhs,$rhs) {return $lhs & $rhs};
sub op_b_or($lhs,$rhs) {return $lhs | $rhs};
sub op_b_xor($lhs,$rhs) {return $lhs ^ $rhs};

sub op_b_not($rhs) {return ~ $rhs};

# ---   *   ---   *   ---
# logic

sub op_not($rhs) {return ! $rhs};

sub op_lt($lhs,$rhs) {return $lhs < $rhs};
sub op_e_lt($lhs,$rhs) {return $lhs <= $rhs};
sub op_gt($lhs,$rhs) {return $lhs > $rhs};
sub op_e_gt($lhs,$rhs) {return $lhs >= $rhs};

sub op_and($lhs,$rhs) {return $lhs && $rhs};
sub op_or($lhs,$rhs) {return $lhs || $rhs};

sub op_xor($lhs,$rhs) {

  my $a=($lhs) ? 1 : 0;
  my $b=($rhs) ? 1 : 0;

  return $lhs ^ $rhs;

};

# ---   *   ---   *   ---
# equality

sub op_match($self,$lhs,$rhs) {

  say $self;
  map {say $ARG} keys %+;
  say "$lhs,$rhs";

};

sub op_eq($lhs,$rhs) {return $lhs eq $rhs};
sub op_ne($lhs,$rhs) {return $lhs ne $rhs};

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    ops=>Lang::eiths(

      $OP_KEYS,
      escape=>1

    ),

  };

# ---   *   ---   *   ---
# rule imports

  ext_rules(

    $PE_COMMON,qw(
    fbeg-parens fend-parens

  ));

  ext_rules($PE_VALUE,qw(value));

# ---   *   ---   *   ---
# operations

  rule('~?<ops> &erew');
  rule(q[

    $<value-op-value>
    &value_ops

    fbeg-parens
    value ops

    fend-parens

  ]);

  rule(q[

    $<ari>
    &erew

    value-op-value ops

  ]);

  rule('$<expr> &expr ari');
  rule('?<opt-expr> &clip expr');

# ---   *   ---   *   ---
# get operators in branch

sub find_ops($self,$branch) {

  state $re=qr{^(?:ops)$};

  return $branch->branches_in(
    $re,keep_root=>0

  );

};

# ---   *   ---   *   ---
# get descriptor for operator
# from the parsed symbol

sub opnit($self,$branch) {

  # remove childless branches
  if(! @{$branch->{leaves}}) {
    Grammar::discard($self,$branch);
    return;

  };

  # get function matching operator
  my $key  = $branch->leaf_value(0);
  my $name = $OPHASH->{$key};

  my $fn   = codefind(
    'Grammar::peso',
    "op_$name"

  );

  my $st={

    fn    => $fn,

    name  => $name,
    key   => $key,

    unary => exists $OP_UNARY->{$key},
    slurp => exists $OP_SLURP->{$key},
    ctx   => exists $OP_CTX->{$key},

    idex  => array_iof($OP_KEYS,$key),

  };

  $branch->{leaves}->[0]->{value}=$st;

};

# ---   *   ---   *   ---
# ^post-parse
#
# find execution data for
# operators in tree

sub value_ops($self,$branch) {};

# ---   *   ---   *   ---
# ^sort operators by precedence

sub opsort($self,$branch) {

  my $st     = $branch->leaf_value(0);
  my $idex   = $branch->{idex};
  my $lv     = $branch->{parent}->{leaves};

  # get operands
  my @move=($st->{unary})
    ? ($lv->[$idex+1])
    : ($lv->[$idex-1],$lv->[$idex+1])
    ;

  my ($st_lv)=$branch->pluck(
    $branch->{leaves}->[0]

  );

  my $st_br=$branch->init('D');
  $st_br->pushlv($st_lv);

  my $v_br=$branch->init('V');
  $v_br->pushlv(@move);

  $branch->{parent}->idextrav();

};

# ---   *   ---   *   ---
# ^pre-run solve operation
#
# ops that are unsolvable at
# this stage are collapsed
# to ease solving them later

sub opsolve($self,$branch) {

  # remove paens
  my $par=$branch->{parent};
  $par->flatten_branch()
  if $par->{value} eq '()';

  # decompose
  my ($D,$V) = @{$branch->{leaves}};

  my @leaves = @{$V->{leaves}};
  my @values = map {
    $self->opvalue($ARG)

  } @leaves;

  # get op is solvable at this stage
  my $valid=

      $self->array_is_value(@leaves)
  &&! $self->array_needs_deref(@values)
  ;

  # restruc
  $self->op_simplify($branch,@values);

  # attempt solving
  $valid=($valid)
    ? $self->op_to_value($branch,@values)
    : $valid
    ;

  return $valid;

};

# ---   *   ---   *   ---
# ^bat

sub array_opsolve($self,$branch) {
  my @ops=$self->find_ops($branch);
  map {$self->opsolve($ARG)} reverse @ops;

};

# ---   *   ---   *   ---
# fetch elements from ops V array

sub opvalue($self,$branch) {

  $branch=($branch->{value} eq '()')
    ? $branch->{leaves}->[0]
    : $branch
    ;

  return $branch->leaf_value(0);

};

# ---   *   ---   *   ---
# collapse op tree branch
# into value node

sub op_to_value($self,$branch,@values) {

  my $type=$values[0]->{type};

  $branch->{value}='value';

  my $o={
    raw  => $self->opres($branch),
    type => $type,

    %{$branch->leaf_value(0)}

  };

  $branch->clear();
  $branch->init($o);

  return 1;

};

# ---   *   ---   *   ---
# ^ease eventual solving of op

sub op_simplify($self,$branch,@values) {

  my ($D,$V) = @{$branch->{leaves}};
  my $st     = $D->leaf_value(0);

  my $o={
    D    => $st,
    V    => \@values,

    type => 'ops',

  };

  $branch->clear();
  $branch->init($o);

};

# ---   *   ---   *   ---
# unwraps value whenever
# it is a nested set of ops

sub denest($self,$o) {

  my $out=(exists $o->{tree})
    ? $o->{tree}
    : $o
    ;

  return $out;

};

# ---   *   ---   *   ---
# get result of operation

sub opres($self,$branch) {

  my $o=($self->is_value($branch))
    ? $branch->leaf_value(0)
    : $branch->{value}
    ;

  my $tree=$self->denest($o);

  return 1 if $o->{type} eq $NULL;
  return ($o->{type} eq 'value')
    ? $self->deref($o)->{raw}
    : $self->opres_flat($o)
    ;

};

# ---   *   ---   *   ---
# ^no branch

sub opres_flat($self,$o,@values) {

  my $tree = $self->denest($o);
  my $st   = $tree->{D};

  @values=(! @values)
    ? @{$tree->{V}}
    : @values
    ;

  # apply deref to @values
  # filter out undef from result of map
  my @deref=grep {defined $ARG} map {
    $self->deref($ARG)

  } @values;

  # ^early exit if values cant
  # be all dereferenced
  return $NULL if @deref ne @values;

  my @args=map {
    (is_hashref($ARG)) ? $ARG->{raw} : $ARG

  } @deref;

  unshift @args,$self if $st->{ctx};

  # call func with derefenced args
  return $st->{fn}->(@args);

};

# ---   *   ---   *   ---
# ^non-runtime crux

sub value_ops_opz($self,$branch) {

  # sort by priority
  my @ops=sort {

     $a->leaf_value(0)->{idex}
  >= $b->leaf_value(0)->{idex}

  } $self->find_ops($branch);

  map {$self->opsort($ARG)} @ops;

  # ^solve from bottom up
  $self->array_opsolve($branch);
  $branch->flatten_branch();

};

# ---   *   ---   *   ---
# recursive op values need deref

sub opconst_flat($self,$o) {

  my $out     = 0;

  my @chk     = ();
  my @pending = ($o);

  # walk operations in expr
  while(@pending) {

    my $op     = shift @pending;
    my @values = @{$op->{V}};

    # ^walk values in operation
    for my $v(@values) {

      if($v->{type} eq 'ops') {
        push @pending,$v;

      } else {
        push @chk,$self->needs_deref($v);

      };

    };

  };

  map {$out|=$ARG} @chk;

  return ! $out;

};

# ---   *   ---   *   ---
# recursive sequence

sub expr($self,$branch) {

  my @ops   = $self->find_ops($branch);
  my @empty = grep {
    ! defined $ARG->{leaves}->[0]

  } @ops;

  # filter out empty tokens
  map {$ARG->{parent}->pluck($ARG)} @empty;
  @ops=grep {defined $ARG->{leaves}->[0]} @ops;

  # ^nit non-empty branches
  map {$self->opnit($ARG)} @ops;

  # merge value-op-value branches
  my $ari    = $branch->{leaves}->[0];
  my @lv     = @{$ari->{leaves}};

  my $anchor = shift @lv;

  # ^walk
  for my $x(@lv) {

    my @merge=($x);

    if($x->{value} eq 'value-op-value') {
      @merge=$x->pluck(@{$x->{leaves}});
      $ari->pluck($x);

    };

    $anchor->pushlv(@merge);

  };

};

# ---   *   ---   *   ---
# ^cleanup

sub expr_ctx($self,$branch) {
  $branch->flatten_branches();

};

sub expr_cl($self,$branch) {

  $branch->flatten_branch()
  if @{$branch->{leaves}} eq 1;

};

# ---   *   ---   *   ---
# extends $PE_VALUE->vex

sub ops_vex($self,$o) {

  my @values=map {
    $self->deref($ARG)

  } @{$o->{V}};

  return {

    raw  => $self->opres_flat($o,@values),
    type => $values[0]->{type}

  };

};

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(expr);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
