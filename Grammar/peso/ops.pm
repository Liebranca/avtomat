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

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # inherits from
  submerge(

    [qw(

      Grammar::peso::common
      Grammar::peso::value

    )],

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

    q[:>]  => 'walk_fwd',
    q[:<]  => 'walk_bak',

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

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $out=int($lhs->{raw}=~ $rhs->{raw});

  if($out) {

    my $matches=$scope->get(
      $scope->path(),q[~:rematch]

    );

    map {
      $matches->{$ARG}//=[];
      push @{$matches->{$ARG}},%+{$ARG};

    } keys %+;

  };

  return $out;

};

sub op_eq($lhs,$rhs) {return $lhs eq $rhs};
sub op_ne($lhs,$rhs) {return $lhs ne $rhs};

# ---   *   ---   *   ---
# loops

sub op_walk_fwd($self,$iter,@args) {

  my $out=undef;

  if($iter) {

    my $o     = $self->deref($iter->{o});
    my $i     = \$iter->{i};

    my @ar    = split $NULLSTR,$o;
    my $limit = int(@ar);

    # get stop
    $out  = $$i < $limit;
    $$i  *= $out;

    goto SKIP if ! $out;

    my @have  = map {$self->vstar($ARG)} @args;
    map {$$ARG->{raw}=$ar[$$i++]} @have;

  };


SKIP:

  return $out;

};

sub op_walk_bak($lhs,$rhs) {

};

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
    fbeg-curly  fend-curly
    fbeg-parens fend-parens

    opt-ncurly

  ));

  ext_rules(

    $PE_VALUE,qw(
    value flg sigil seal bare

  ));

# ---   *   ---   *   ---
# sub-scopes within expressions

  rule(q[

    $<invoke>

    fbeg-curly
    value opt-ncurly

    fend-curly

  ]);

# ---   *   ---   *   ---
# ^post-parse

sub invoke($self,$branch) {

  if(@{$branch->{leaves}} < 3) {
    Grammar::discard($self,$branch);
    return;

  };

  my $depth=$branch->leaf_value(0);
  my $value=$branch->{leaves}->[1];
  my $nterm=$branch->{leaves}->[2];

  my $st=$self->invoke_sort(
    $value,$nterm,$depth

  );

  $branch->clear();
  $branch->init($st);

  $branch->{value}='unsorted_invoke';

};

# ---   *   ---   *   ---
# resolve type of processing
# to be applied to an invoke
# by evaluating its args

sub invoke_sort($self,$value,$nterm,$depth) {

  # get value hashref
  my $st=$value->leaf_value(0);

  # ^first arg assumed value of invoke
  # if opt-nterm was not passed
  my $raw=(defined $nterm->{leaves}->[0])
    ? $nterm->leaf_value(0)
    : $st->{raw}
    ;

  # ^run type-chk on hashref
  my $type=$self->get_invoke_type($st);

  return $self->{mach}->vice(

    'voke',

    raw   => $raw,
    depth => $depth,

    spec  => [$type],

  );

};

# ---   *   ---   *   ---
# dets type of invoke

sub get_invoke_type($self,$st) {

  state @chk_list=(
    'is_invoke_lit',

  );

  my $type=undef;

  # ^run chks from array
  for my $f(@chk_list) {
    $type=$self->$f($st);
    last if $type;

  };

  # ^default to type of value hashref
  $type=$st->{type} if ! $type;
  return $type;

};

# ---   *   ---   *   ---
# ^get invokes type is given
# by its value hashref

sub is_invoke_lit($self,$st) {

  state $lit_type  = qr{^(flg|seal|bare)$}x;
  state $lit_value = qr{^(re)$}x;

  my $out=undef;

  # ^non-numeric/non-str/non-op
  if($st->{type} =~ $lit_type
  && $st->{raw}  =~ $lit_value) {
    $out=$st->{raw};

  };

  return $out;

};

# ---   *   ---   *   ---
# parents one invoke to another
# accto their depth

sub invoke_ctx($self,$branch) {

  return if $branch->{value} eq 'invoke';

  my $st  = $branch->leaf_value(0);
  my $par = $branch->{parent};

  my @lv  = $self->find_invokes($par);

  goto SKIP if ! $st->{depth} ||! @lv;

  # get nearest invoke
  my @lower=sort {
    $a->leaf_value(0)->{depth}
  > $b->leaf_value(0)->{depth}

  } grep {

    $ARG->leaf_value(0)->{depth}
  < $st->{depth};

  } reverse @lv;

  # ^anchor to it
  my $other=pop @lower;
  $other->pushlv($branch) if defined $other;


SKIP:

  $branch->{value}='invoke';

};

# ---   *   ---   *   ---
# ^converts invoke to value

sub invoke_ord($self,$branch) {

  my $lv=$branch->{leaves}->[0];
  my $st=$lv->{value};

  $st->type_pop('voke');
  $branch->pluck($lv);

  # solve nested
  map {
    $self->invoke_ord($ARG)

  } @{$branch->{leaves}};

  # ^TODO: actually solve ;>
  $branch->clear();
  $branch->{value}='value';
  $branch->init($st);

};

# ---   *   ---   *   ---
# get invokes in branch

sub find_invokes($self,$branch) {

  state $re=qr{^invoke$};

  return $branch->branches_in(
    $re,keep_root=>0

  );

};

# ---   *   ---   *   ---
# ^unsorted

sub find_uinvokes($self,$branch) {

  state $re=qr{^unsorted_invoke$};

  return $branch->branches_in(
    $re,keep_root=>0

  );

};

# ---   *   ---   *   ---
# prematurely solve invokes
# of a branch

sub invokes_solve($self,$branch) {

  map {
    $self->invoke_ctx($ARG)

  } $self->find_uinvokes($branch);

  map {
    $self->invoke_ord($ARG)

  } $self->find_invokes($branch);

};

# ---   *   ---   *   ---
# operations

  rule('|<value-or-invoke> &clip value invoke');
  rule('~?<ops> &erew');
  rule(q[

    $<value-op-value>
    &value_ops

    fbeg-parens
    value-or-invoke ops

    fend-parens

  ]);

  rule(q[

    $<ari>
    &erew

    value-op-value ops

  ]);

# ---   *   ---   *   ---
# ^all together

  rule('$<expr> &expr ari');
  rule('?<opt-expr> &clip expr');
  rule('?<rec-expr> &erew expr');

# ---   *   ---   *   ---
# get operators in branch

sub find_ops($self,$branch) {

  state $re=qr{^ops$};

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

  my $st=$self->{mach}->vice(

    'ops',

    fn    => $fn,

    unary => exists $OP_UNARY->{$key},
    slurp => exists $OP_SLURP->{$key},
    ctx   => exists $OP_CTX->{$key},

    prio  => array_iof($OP_KEYS,$key),

  );

  $branch->{leaves}->[0]->{value}=$st;

};

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

  $st->{V}=[map {$self->opvalue($ARG)} @move];
  $branch->{parent}->pluck(@move);

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
  my $st     = $branch->leaf_value(0);
  my @values = @{$st->{V}};

  my $flat   = map {
    $ARG->{type} ne 'ops'

  } @values;

  # get op is solvable at this stage
  my $const=0;
  if($flat) {

    my @consts=
      $self->array_const_deref(@values);

    if(@consts) {
      @values = @consts;
      $const  = 1;

      $self->op_to_value($branch);

    };

  };

  $st->{const}=$const;
  return $const;

};

# ---   *   ---   *   ---
# ^bat

sub array_opsolve($self,$branch) {

  my @ops=$self->find_ops($branch);
  my $valid=int(grep {$ARG} map {
    $self->opsolve($ARG)

  } reverse @ops) == @ops;

  return $valid;

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

sub op_to_value($self,$branch) {

  my $st     = $branch->leaf_value(0);

  my $values = $st->{V};
  my $type   = $values->[0]->{type};

  $branch->{value}='value';

  my $o=$st->dup(
    raw=>$self->opres($branch),
    %{$branch->leaf_value(0)}

  );

  $o->type_pop('ops');

  $branch->clear();
  $branch->init($o);

  return 1;

};

# ---   *   ---   *   ---
# unwraps value whenever
# it is a nested set of ops

sub denest($self,$o) {

  my $out=(defined $o->{tree})
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

  return 1 if $tree eq $NULL;
  return 1 if $tree->{type} eq $NULL;
  return $tree->{raw} if $tree->{type} eq 'const';

  my $out;

  if($tree->{type} eq 'value') {

    $out=$self->deref($tree);
    $out=(defined $out)
      ? $out->{raw}
      : undef
      ;

  } else {
    $out=$self->opres_flat($tree);

  };

  return $out;

};

# ---   *   ---   *   ---
# ^no branch

sub opres_flat($self,$o,@values) {

  my $tree = $self->denest($o);

  @values=(! @values)
    ? @{$tree->{V}}
    : @values
    ;

  my @deref=();

  # apply deref to @values
  # filter out undef from result of map
  if(

    ! $tree->{const}
  &&! ($tree->{type} eq 'iter')

  ) {

    @deref=grep {defined $ARG} map {
      $self->deref($ARG)

    } @values;

  # ^values already dereferenced
  } else {
    @deref=@values;

  };

  # ^early exit if values cant
  # be all dereferenced
  return undef if @deref ne @values;

  my @args=();

  if($tree->{type} eq 'iter') {
    @args=@deref;

  } else {
    @args=map {
      (is_hashref($ARG)) ? $ARG->{raw} : $ARG

    } @deref;

  };

  unshift @args,$self if $tree->{ctx};

  # call func with derefenced args
  return $tree->{fn}->(@args);

};

# ---   *   ---   *   ---
# ^non-runtime crux

sub value_ops_opz($self,$branch) {

  # sort by priority
  my @ops=sort {

     $a->leaf_value(0)->{prio}
  >= $b->leaf_value(0)->{prio}

  } $self->find_ops($branch);

  map {$self->opsort($ARG)} @ops;

  # ^solve from bottom up
  my $const=$self->array_opsolve($branch);

  # ^collapse if constant
  if($const) {

    my $lv   = $branch->{leaves}->[0];
    my $o    = $lv->leaf_value(0);
       $lv   = $lv->{leaves}->[0];

    my $type = 'const';
    my $raw  = $o->{raw};

    $lv->{value}=$self->{mach}->vice(
      'const',raw=>$raw

    );

  };

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
        my $const=$self->const_deref($v);
        push @chk,(defined $const && $const);

      };

    };

  };

  map {$out|=$ARG} @chk;

  return ! $out;

};

# ---   *   ---   *   ---
# recursive sequence

sub expr($self,$branch) {

  $self->expr_pluck_empty($branch);

  my @ops   = $self->find_ops($branch);
  my @empty = grep {
    ! defined $ARG->{leaves}->[0]

  } @ops;

  # filter out empty tokens
  map {$ARG->{parent}->pluck($ARG)} @empty;
  @ops=grep {defined $ARG->{leaves}->[0]} @ops;

  # ^nit non-empty branches
  map {$self->opnit($ARG)} @ops;

  my $ari=$branch->{leaves}->[0];
  $self->expr_merge($ari);

};

# ---   *   ---   *   ---
# merge value-op-value branches

sub expr_merge($self,$branch) {

  my @lv     = @{$branch->{leaves}};
  my $anchor = shift @lv;

  # ^walk
  for my $x(@lv) {

    my @merge=($x);

    if($x->{value} eq 'value-op-value') {
      @merge=$x->pluck(@{$x->{leaves}});
      $branch->pluck($x);

    };

    $anchor->pushlv(@merge);

  };

};

# ---   *   ---   *   ---
# ^get rid of failed matches

sub expr_pluck_empty($self,$branch) {

  state $re=qr{(?:
    value\-or\-invoke
  | value\-op\-value
  | ops

  )}x;

  map {
    my @ar=$branch->leafless();

    map  {$ARG->{parent}->pluck($ARG)}
    grep {$ARG->{value}=~ $re} reverse @ar

  } 0..1;

};

# ---   *   ---   *   ---
# ^cleanup

sub expr_ctx($self,$branch) {

  state $re=qr{^rec\-expr$};

  my $par=$branch->{parent};

  $branch->flatten_branches();
  $branch->flatten_branch();

  if(

     defined $par
  && $par->{value} eq 'rec-expr'

  && defined $par->{parent}

  ) {

    my $root=$par->{parent};

    if(! defined $root->{done}) {

      $root->{done}=1;

      my @rec = $root->branches_in($re);
      my $beg = shift @rec;

      map {

        my @lv=map {
          $ARG->flatten_branches();

        } @{$ARG->{leaves}};

        $beg->pushlv(@lv);
        $root->pluck($ARG);

      } @rec;

      $self->expr_merge($par);

    };

  };

};

# ---   *   ---   *   ---
# extends $PE_VALUE->vex

sub ops_vex($self,$o) {

  my @values=map {
    $self->deref($ARG)

  } @{$o->{V}};

  return {

    const=>1,
    value=>{

      raw   => $self->opres_flat($o,@values),
      type  => (is_hashref($values[0]))
        ? $values[0]->{type}
        : $NULL
        ,

    },

  };

};

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(rec-expr);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
