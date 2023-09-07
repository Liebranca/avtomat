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
  use Arstd::Re;
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

  our $VERSION = v0.00.9;#b
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

    q[->]  => 'm_attr',
    q[->*] => 'm_call',

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
# ^makes note of ops that
# cannot be const'd

  Readonly our $OP_NCONST=>{
    q[->]  => 1,
    q[->*] => 1,

  };

# ---   *   ---   *   ---
# ^makes note of ops taking slurp args

  Readonly our $OP_SLURP=>{};

# ---   *   ---   *   ---
# ^makes note of ops requiring ctx access

  Readonly our $OP_CTX=>{

    q[->]  => 1,
    q[->*] => 1,
    q[~=]  => 1,

  };

# ---   *   ---   *   ---
# get ref to member var

sub op_m_attr($self,$lhs,$rhs) {

  my $a=$lhs->get();
  my $b=$rhs->get();

  return (is_hashref($a))
    ? \$a->{$b}
    : undef
    ;

};

# ---   *   ---   *   ---
# get wraps around member F call

sub op_m_call($self,$lhs,$rhs) {

  my $obj = $lhs->get();
  my $fn  = $rhs->get();

  if(exists $lhs->{procs}->{$fn}) {
    $fn=$lhs->{procs}->{$fn};
    return sub (@args) {$fn->($obj,@args)};

  } else {
    return sub (@args) {$obj->$fn(@args)};

  };

};

# ---   *   ---   *   ---
# math

sub op_pow($lhs,$rhs) {
  $lhs->rget() ** $rhs->rget()

};

sub op_mul($lhs,$rhs) {
  $lhs->rget() * $rhs->rget();

};

sub op_mod($lhs,$rhs) {
  $lhs->rget() % $rhs->rget()

};

sub op_div($lhs,$rhs) {
  return $lhs->rget() / $rhs->rget()

};

sub op_add($lhs,$rhs) {
  return $lhs->rget() + $rhs->rget();

};

sub op_sub($lhs,$rhs) {
  $lhs->rget() - $rhs->rget()

};

# ---   *   ---   *   ---
# bits

sub op_lshift($lhs,$rhs) {
  $lhs->rget() << $rhs->rget()

};

sub op_rshift($lhs,$rhs) {
  $lhs->rget() >> $rhs->rget()

};

sub op_b_and($lhs,$rhs) {
  $lhs->rget() & $rhs->rget()

};

sub op_b_or($lhs,$rhs) {
  $lhs->rget() | $rhs->rget()

};

sub op_b_xor($lhs,$rhs) {
  $lhs->rget() ^ $rhs->rget()

};

sub op_b_not($rhs) {
  ~ $rhs->rget()

};

# ---   *   ---   *   ---
# logic

sub op_not($rhs) {
  ! $rhs->rget()

};

sub op_lt($lhs,$rhs) {
  $lhs->rget() < $rhs->rget()

};

sub op_e_lt($lhs,$rhs) {
  $lhs->rget() <= $rhs->rget()

};

sub op_gt($lhs,$rhs) {
  $lhs->rget() > $rhs->rget()

};

sub op_e_gt($lhs,$rhs) {
  $lhs->rget() >= $rhs->rget()

};

sub op_and($lhs,$rhs) {
  $lhs->rget() && $rhs->rget()

};

sub op_or($lhs,$rhs) {
  $lhs->rget() || $rhs->rget()

};

sub op_xor($lhs,$rhs) {

  my $a=($lhs->rget()) ? 1 : 0;
  my $b=($rhs->rget()) ? 1 : 0;

  return $a ^ $b;

};

# ---   *   ---   *   ---
# equality

sub op_match($self,$lhs,$rhs) {

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $out=int($lhs->get()=~ $rhs->get());

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

sub op_eq($lhs,$rhs) {
  $lhs->rget() eq $rhs->rget()

};

sub op_ne($lhs,$rhs) {
  $lhs->rget() ne $rhs->rget()

};

# ---   *   ---   *   ---
# array fetch

sub op_subscript($self,$ar,$idex) {

  my $out=undef;

  if($ar && $ar->{scope}) {

    # get ctx
    my $scope = $ar->{scope};
    my $path  = $ar->{path};

    # get node storing var
    my $base=$scope->{tree}->fetch(
      path=>$path

    );

    # ^get nebor node at offset
    my $ahead=$base->neigh($idex->{raw});

    # ^deref
    $out=$ahead->leaf_value(0)->{raw}
    if $ahead;

  };

  return $out;

};

# ---   *   ---   *   ---
# loops

sub op_walk_fwd($self,$iter,@args) {

  my $out=undef;
  my $src=shift @args;

  if($src) {

    my $o     = $self->deref($src);
    my $i     = \$iter->{i};

    my @ar    = split $NULLSTR,$o->{raw};
    my $limit = int(@ar);

    # get stop
    $out  = $$i < $limit;
    $$i  *= $out;

    goto SKIP if ! $out;

    my @have=map {$self->vstar($ARG)} @args;
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

    ops   => re_eiths($OP_KEYS,opscape=>1),
    lit_t => qr{^(?: flg|seal|bare) $}x,

  };

# ---   *   ---   *   ---
# rule imports

  ext_rules(

    $PE_COMMON,qw(

    fbeg-curly  fend-curly
    fbeg-parens fend-parens
    fbeg-brak fend-brak

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

  # ^fcalls are special ;>
  if($type eq 'fcall') {
    $raw=[$st->{raw},$raw];

  };


  # ^repack
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
    'is_invoke_fcall',

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

  state $lit_value=qr{^(re)$}x;

  my $out=undef;

  # ^non-numeric/non-str/non-op
  if($st->{type} =~ $REGEX->{lit_t}
  && $st->{raw}  =~ $lit_value) {
    $out=$st->{raw};

  };

  return $out;

};

# ---   *   ---   *   ---
# ^ipret invoke type as a
# user-def fcall

sub is_invoke_fcall($self,$st) {

  my $out=undef;

  if($st->{type}=~ $REGEX->{lit_t}) {
    $out='fcall';

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

sub invoke_cl($self,$branch) {

  my $lv=$branch->{leaves}->[0];
  my $st=$lv->{value};

  $st->type_pop('voke');
  $branch->pluck($lv);

  # solve nested
  map {
    $self->invoke_cl($ARG)

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
    $self->invoke_cl($ARG)

  } $self->find_invokes($branch);

};

# ---   *   ---   *   ---
# operations

  rule('|<value-or-invoke> &clip value invoke');
  rule('~?<ops> &erew');

  rule(q[

    $<value-op-value>
    &value_ops

    fbeg-parens fbeg-brak
    value-or-invoke ops

    fend-brak fend-parens

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
  rule('|<rec-expr> &erew expr value-or-invoke');

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
    'Grammar::peso::ops',
    "op_$name"

  );

  my $st=$self->{mach}->vice(

    'ops',

    fn     => $fn,
    key    => $key,

    unary  => exists $OP_UNARY->{$key},
    slurp  => exists $OP_SLURP->{$key},
    ctx    => exists $OP_CTX->{$key},
    nconst => exists $OP_NCONST->{$key},

    prio   => array_iof($OP_KEYS,$key),

  );

  $branch->{leaves}->[0]->{value}=$st;

};

# ---   *   ---   *   ---
# ^sort operators by precedence

sub opsort($self,$branch) {

  my $st   = $branch->leaf_value(0);
  my $idex = $branch->{idex};
  my $lv   = $branch->{parent}->{leaves};

  # get operands
  my @move=($st->{unary})
    ? ($lv->[$idex+1])
    : ($lv->[$idex-1],$lv->[$idex+1])
    ;


  # ^perform move if operands not set
  if(! @{$st->{V}}) {

    $st->{V}=[map {$self->opvalue($ARG)} @move];
    $branch->{parent}->pluck(@move);

  };

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

  my $flat   = int( grep {
    $ARG->{const} &&! $ARG->{nconst};

  } @values) == @values;

  # get op is solvable at this stage
  my $const=0;
  if($flat &&! $st->{nconst}) {

    my @consts=
      $self->array_const_deref(@values);

    if(@consts) {
      @{$st->{V}}=@consts;
      $const=1;

      $self->op_to_value($branch);

    };

  };

  $st->{const}=$const;
  return $const &&! $st->{nconst};

};

# ---   *   ---   *   ---
# ^bat

sub array_opsolve($self,$branch) {

  my @ops=$self->find_ops($branch);

  # solve from bottom up
  my @const = map {
    $self->opsolve($ARG)

  } reverse @ops;

  # give all ops were solved
  return int(grep {$ARG} @const) == @ops;

};

# ---   *   ---   *   ---
# fetch value branch of value-op-value

sub opleaf($self,$branch) {

  state $nested=qr{
    (?: \{\} | \(\) | \[\] )

  }x;

  return ($branch->{value}=~ $nested)
    ? $branch->{leaves}->[0]
    : $branch
    ;

};

# ---   *   ---   *   ---
# ^get value of branch itself

sub opvalue($self,$branch) {
  return $self->opleaf($branch)->leaf_value(0);

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
# get result of operation

sub opres($self,$branch) {

  my $tree=($self->is_value($branch))
    ? $branch->leaf_value(0)
    : $branch->{value}
    ;

  return 1 if $tree eq $NULL;
  return 1 if $tree->{type} eq $NULL;
  return $tree->{raw} if $tree->{type} eq 'const';


  my ($type,$out);

  if($tree->{type} ne 'ops') {

    $out=$self->deref($tree);

    ($type,$out)=(defined $out)
      ? ($out->{type},$out->{raw})
      : (undef,undef)
      ;

  } else {
    ($type,$out)=$self->opres_flat($tree);

  };

  return $out;

};

# ---   *   ---   *   ---
# ^no branch

sub opres_flat($self,$tree) {

  # filter out undef from deref'd
  my @values = $self->opargs($tree);
  my @deref  = grep {defined $ARG} @values;


  # ^early exit if values cant
  # be all dereferenced
  return undef if @deref ne @values;


  # base result type on first operand
  my $type=(defined $values[0]->{type})
    ? $values[0]->{type}
    : 'const'
    ;

  my @args=();

  # nevermind this, deprecated iter logic
  # 100% needs rewrit
  if($tree->{type} eq 'iter') {
    @args=($tree,@deref);

  # ^get value from args
  } else {
    @args=map {
      (is_hashref($ARG)) ? $ARG->{raw} : $ARG

    } @deref;

  };

  unshift @args,$self if $tree->{ctx};

  # call func with derefenced args
  my $out=$tree->{fn}->(@args);
  $tree->{raw}=$out;


  return $type=>$out;

};

# ---   *   ---   *   ---
# ^non-runtime crux

sub value_ops_walk($self,$branch) {

  # group subscript ops with their
  # corresponding values
  $self->subscript_sort($branch);

  # sort ops && operands by priority
  $self->value_ops_sort($branch);

  # ^collapse into value branch
  # if op is solvable at this stage
  $self->opconst_collapse($branch)
  if $self->array_opsolve($branch);


  return $branch->flatten_branch();

};

# ---   *   ---   *   ---
# pairs value to matching subscript

sub subscript_sort($self,$branch) {

  state $brak=qr{^\[\]$}x;

  # [N] switches meaning when
  # used inside a declaration
  my $f    = $self->{frame};
  my $decl = (defined $f->{-cdecl})
    ? defined $f->{-cdecl}->[-1]
    : undef
    ;

  map {

    my $value=$ARG->next_branch(-1);
    $ARG->pushlv($value);

    ($decl)
      ? $self->subscript_to_decl($ARG)
      : $self->subscript_to_ops($ARG)
      ;

  } $branch->branches_in($brak);

};

# ---   *   ---   *   ---
# ^transforms name[idex] into
# an array declaration

sub subscript_to_decl($self,$branch) {

  my $lv    = $branch->{leaves};

  my $size  = $lv->[0]->leaf_value(0);
  my $bare  = $lv->[1]->leaf_value(0);

  my $names = [$bare->{raw},map {
    "$bare->{raw}\[$ARG]"

  } 1..$size->{raw}-1];

  my $st=$self->{mach}->vice(

    'array_decl',
    raw=>$names,

  );

  $branch->{value}='value';

  $branch->clear();
  $branch->init($st);

};

# ---   *   ---   *   ---
# ^transforms name[idex] into
# an operator branch

sub subscript_to_ops($self,$branch) {

  my @values=map {
    $ARG->leaf_value(0);

  } reverse @{$branch->{leaves}};

  my $st=$self->{mach}->vice(

    'ops',

    V     => \@values,

    ctx   => 1,
    prio  => 0,

    fn    => codefind(
      'Grammar::peso::ops',
      'op_subscript'

    ),

  );

  $branch->{value}='ops';

  $branch->clear();
  $branch->init($st);

};

# ---   *   ---   *   ---
# sort ops of an expression
# by their priority

sub value_ops_sort($self,$branch) {

  my @ops=map {
    ($ARG->{_vos_root},$ARG->{_vos_depth})=
      $ARG->root();

    $ARG;

  } $self->find_ops($branch);

  @ops=sort {(

  (  $a->{_vos_depth}
  == $b->{_vos_depth} )

  && $a->leaf_value(0)->{prio}
  >  $b->leaf_value(0)->{prio}

  ) || (

     $a->{_vos_depth}
  <  $b->{_vos_depth}

  )} @ops;

  map {$self->opsort($ARG)} @ops;

};

# ---   *   ---   *   ---
# collapses operator tree
# when operation is solved

sub opconst_collapse($self,$branch) {

  # get leaf holding value
  my $lv   = $self->opleaf(
    $branch->{leaves}->[0]

  );


  # ^get value
  my $o    = $lv->leaf_value(0);
  my $dst  = $lv->{leaves}->[0];

  my $type = $o->{type};
  my $spec = $o->{spec};
  my $raw  = $o->{raw};

  # ^defaults for undef
  $type//='const';

  $dst->{value}=$self->{mach}->vice(
    $type,raw=>$raw

  );

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

  my $par=$self->{parent};

  $branch->flatten_branches();
  $branch->flatten_branch();

  my @rec    = $self->{p3}->branches_in($re);

  my $first  = shift @rec;
  my $anchor = $first->{leaves}->[0];

  map {
    $anchor->pushlv($ARG->pluck_all());
    $self->{p3}->pluck($ARG);

  } @rec;


  if(defined $par
  && defined $par->{parent}) {

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

  my ($type,$raw)=(! $o->{const})
    ? $self->opres_flat($o)
    : ($o->{type},$o->{raw})
    ;

  $o->{raw}=$raw=(defined $raw && $raw ne $NULL)
    ? $raw
    : undef
    ;

  return $self->{mach}->vice(

    $type,

    const => defined $raw,
    raw   => $raw,

  );

};

# ---   *   ---   *   ---
# ^dereferences operands

sub opargs($self,$o) {

  state $explicit=qr{^(?:
    ->* | ->

  )$}x;

  state $explicit_allow=qr{^(?:
    flg | str | ops | obj

  )$}x;


  # values already dereferenced,
  # return as-is
  return @{$o->{V}}

  if $o->{const}
  && $o->{type} ne 'iter';


  # ^else dereference
  my @out=();


  # for -> m_attr and ->* m_call:
  # righthand operand should not be
  # deref'd unless explicitly stated
  if($o->{key}=~ $explicit) {

    my ($lhs,$rhs)=@{$o->{V}};

    @out    = (0,0);

    $out[0] = $self->deref($lhs,key=>1);
    $out[1] = ($rhs->{type}=~ $explicit_allow)
      ? $self->deref($rhs,key=>1)
      : $rhs
      ;


  # ^all operands deref'd
  } else {

    @out=map {
      $self->deref($ARG,key=>1)

    } @{$o->{V}};

  };


  return @out;

};

# ---   *   ---   *   ---
# crux

sub recurse($class,$branch,%O) {

  state $re=qr{^(?:rec\-expr)$};

  # make subtree from branch
  my $ice=$class->parse($branch->{value},%O);

  # ^trim
  my @expr=$ice->{p3}->branches_in($re);
     @expr=map {$ARG->pluck_all()} @expr;

  # ^ensure all subtrees solved
  return map {

    if($ARG->{value} eq 'value-op-value') {
      $ARG=$ice->value_ops_opz($ARG);

    };

    $ARG;

  } @expr;

};

# ---   *   ---   *   ---
# ^indirect

sub expr_collapse($self,$branch,$idex=0) {

  $self->expr_ctx(
    $branch->{leaves}->[$idex]

  );

  $self->value_ops_opz(
    $branch->{leaves}->[$idex]

  );

};

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(rec-expr);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
