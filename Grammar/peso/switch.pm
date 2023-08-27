#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO SWITCH
# if/else
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::switch;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::std;
  use Grammar::peso::ops;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_value();
  $PE_STD->use_eye();

  # class attrs
  fvars('Grammar::peso::common');

# ---   *   ---   *   ---
# GBL

  our $REGEX={
    q[switch-key]=>re_pekey(qw(on or off)),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<switch-key>');
  rule('%<from=from>');

  rule('$<switch> switch-key opt-nterm term');

# ---   *   ---   *   ---
# ^post-parse

sub switch($self,$branch) {

  my ($type,$expr,$from,$array)=
    $self->rd_name_nterm($branch);

  $type=lc $type;

  my $st={
    type => $type,
    lvl  => 0,

  };

  my $fn=$NULLSTR;

  # switch is iter
  if($from) {

    throw_incomplete_iter()
    unless $from && $array;

    $fn='iter_expr';

    nyi('VLIST-FROM-ARRAY');


  # ^plain case
  } else {

    # no condition provided means
    # always true
    $expr=(! $expr)
      ? $self->{mach}->vice('num',raw=>1)
      : $expr->[0]
      ;

    $st={%$st,expr=>$expr};
    $fn=($type eq 'off')
      ? "switch_off"
      : "switch_on"
      ;

  };


  # ^repack
  $branch->{value}=$type;
  $branch->clear();

  $branch->init($st);

  # ^fork into new node type
  $branch->fork_chain(

    dom  => ref $self,
    name => $fn,

    skip => 0,

  );

};

# ---   *   ---   *   ---
# ^errme

sub throw_incomplete_iter() {

  errout(

    q[[ctl]:%s used on switch but ]
  . q[no array was provided],

    lvl  => $AR_FATAL,
    args => ['from'],

  );

};

# ---   *   ---   *   ---
# ^adds nesting data

sub switch_case($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  my $st   = $branch->leaf_value(0);

  $st->{lvl}=$$nest-1;

};

# ---   *   ---   *   ---
# if

sub switch_on($self,$branch) {

  # inc nesting lvl
  if($branch->{value} eq 'on') {

    my $f    = $self->{frame};
    my $nest = \$f->{-nest}->{switch};

    $$nest++;

  };

  $self->switch_case($branch);

};

# ---   *   ---   *   ---
# ^procs

sub switch_on_ctx($self,$branch) {
  $self->switch_sort($branch);

};

sub switch_on_walk($self,$branch) {
  $self->switch_simplify($branch);

};

# ---   *   ---   *   ---
# ^exec

sub switch_on_run($self,$branch) {

  my $st   = $branch->{value};
  my $expr = $st->{expr};

  my $e    = $self->deref($expr);


  $self->{c3}->jmp(
    $branch->next_branch()

  ) if ! $e->get();

};

# ---   *   ---   *   ---
# xlate on/or

sub switch_on_perl_xlate($self,$branch) {

  my $st    = $branch->{value};

  my $type  = $st->{type};
  my $expr  = $st->{expr};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};


  # is if/else if
  my $hed  = ($type eq 'or')
    ? '} elsif'
    : 'if'
    ;

  # ^translate expresion
  my ($e)=$expr->perl_xlate(id=>0,scope=>$scope);

  $branch->{perl_xlate}="$hed ($e) {\n";

};

# ---   *   ---   *   ---
# fi

sub switch_off($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  $self->switch_case($branch);
  $$nest--;

};

sub switch_off_ctx($self,$branch) {
  $branch->{value}=$branch->leaf_value(0);
  $branch->clear();

};

sub switch_off_perl_xlate($self,$branch) {
  $branch->{perl_xlate}="};\n";

};

# ---   *   ---   *   ---
# adds jmp off at end of switch case

sub switch_end($self,$branch) {

  state $re=qr{^off$};

  my $stop=$branch->next_branch();

  if(

     $branch->{value} ne 'off'
  && $stop->{value} ne 'off'

  ) {

    my $jmp = $branch->init('jmp');
    my $par = $branch->{parent};
    my $f   = $self->{frame};

    $stop=$par->match_from($branch,$re);

    $jmp->init($stop);
    $jmp->fork_chain(

      dom  => ref $self,
      name => 'jmp',

      skip => $f->{-npass}+1

    );

  };

};

# ---   *   ---   *   ---
# det if case can be resolved
# before runtime

sub switch_const($self,$branch) {

  my $st    = $branch->{value};

  my $expr  = $st->{expr};
  my $type  = $expr->{type};

  # handle non-operation
  if($type ne 'ops') {
    return $expr->{const};

  };


  # ^get operands are all constant
  my $const = $self->opconst_flat($expr);

  # ^attempt solving operation now
  # as a double check
  $const=($const)
    ? $self->opres_flat($expr)
    : undef
    ;


  return $const && $const != $NULL;

};

# ---   *   ---   *   ---
# ^optimize out constant branches

sub switch_simplify($self,$branch) {

  my $i     = 0;
  my $cur   = 0;
  my $prev  = 0;

  my $ahead = $branch;

  return if ! $self->switch_const($branch);


REPEAT:

  my $st   = $ahead->{value};
  my $type = $st->{type};
  my $expr = $st->{expr};


  # solve constant branch
  $cur  = ($expr->{type} eq 'ops')
    ? $self->opres_flat($expr)
    : $expr->get()
    ;

  $prev = ($cur &&! $prev);

  # ^stop at truth
  $ahead=(! $prev)
    ? $self->switch_flatten($ahead)
    : $self->switch_pluck($ahead)
    ;


  goto REPEAT if $type ne 'off';

};

# ---   *   ---   *   ---
# ^replace evaluation with
# branch leaves

sub switch_flatten($self,$branch) {

  # get branch after this one
  my $ahead = $branch->next_branch();

  my $st    = $ahead->{value};
  my $type  = $st->{type};


  # ^add jump if it's not last
  # node in switch
  if($type ne 'off') {
    my $jmp=$branch->{leaves}->[-1];
    $branch->pluck($jmp);

  };


  # clear
  $branch->flatten_branch();
  return $ahead;

};

# ---   *   ---   *   ---
# ^removes entire branch

sub switch_pluck($self,$branch) {

  my $ahead=$branch->next_branch();
  $branch->{parent}->pluck($branch);

  return $ahead;

};

# ---   *   ---   *   ---
# find next case in switch
# parent in-between nodes to branch

sub switch_sort($self,$branch) {

  state $re=qr{^(?:or|off)$}x;

  my $par    = $branch->{parent};
  my $anchor = $branch;

  my @lv     = ();
  my $helper = $branch->{leaves}->[0];
  my $lvl    = $helper->{value}->{lvl};


REPEAT:

  push @lv,$par->match_until(
    $anchor,$re,
    inclusive=>1

  );

  my $stop = pop @lv;
  my $st   = $stop->leaf_value(0);

  $anchor=$stop;
  goto REPEAT if $st->{lvl} != $lvl;


  $branch->pushlv(@lv);
  $self->switch_end($branch);


  $branch->{value}=$helper->{value};
  $branch->pluck($helper);

};

# ---   *   ---   *   ---
# jump to node

  rule('%<jmp-key=jmp>');
  rule('<jmp> jmp-key value');

# ---   *   ---   *   ---
# ^post-parse

sub jmp($self,$branch) {};

sub jmp_ord($self,$branch) {
  $branch->{value}=$branch->leaf_value(0);
  $branch->clear();

};

sub jmp_run($self,$branch) {
  $self->{c3}->jmp($branch->{value});

};

# ---   *   ---   *   ---
# ^jump to top of branch

  rule('%<rept-key=rept>');
  rule('<rept> rept-key');

# ---   *   ---   *   ---
# ^post-parse

sub rept($self,$branch) {
  $branch->clear();

};

sub rept_ctx($self,$branch) {

  my $f=$self->{frame};
  $branch->init($branch->{parent});

  $branch->fork_chain(

    dom  => ref $self,
    name => 'jmp',

    skip => $f->{-npass}+1

  );

};

## ---   *   ---   *   ---
#
# DEPRECATED
# reqs a rewrit!
#
## vars from iter
#
#sub iter_expr($self,$branch) {
#
#  my $lv  = $branch->{leaves};
#  my $key = $lv->[1];
#
#  $branch->pluck($key);
#  $lv=$branch->{leaves};
#
#  my @vlist = $lv->[0]->branch_values();
#  my $iter  = $lv->[1]->leaf_value(0);
#
#  my $st=$self->{mach}->vice(
#
#    'iter',
#
#    spec => ['ops'],
#
#    V    => \@vlist,
#    src  => $iter,
#
#  );
#
#  $branch->clear();
#  $branch->{value}=$st;
#
#};
#
## ---   *   ---   *   ---
## ^bind vars
#
#sub iter_expr_ctx($self,$branch) {
#
#  # get ctx
#  my $mach  = $self->{mach};
#  my $st    = $branch->{value};
#
#  # ^unpack
#  my @vars = @{$st->{V}};
#  my $src  = $st->{src};
#
#  # get element size
#  my $ref   = $self->deref($src);
#  my $width = $ref->{width};
#
#  # ^bind vars
#  my @names  = map {$ARG->{raw}} @vars;
#  my @values = map {
#    $mach->null($ref->{type})
#
#  } @vars;
#
#  $self->bind_decls(
#    $width,\@names,\@values
#
#  );
#
#};
#
## ---   *   ---   *   ---
## ^xform to operator
#
#sub iter_expr_ord($self,$branch) {
#
#  my $st=$branch->{value};
#  my $fn=codefind(
#    'Grammar::peso',
#    'op_walk_fwd',
#
#  );
#
#  $st->{fn}  = $fn;
#  $st->{ctx} = 1;
#
#  $st->{V}   = [
#    $st->{src},
#    @{$st->{V}},
#
#  ];
#
#  $branch->init($st);
#  $branch->{value}='ops';
#
#};
#

# ---   *   ---   *   ---
# do not make a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
