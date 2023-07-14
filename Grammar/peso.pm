#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO GRAMMAR
# Recursive swan song
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso;

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
  use Grammar::peso::ops;
  use Grammar::peso::re;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.6;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # inherits from
  submerge(

    [qw(

      Grammar::peso::common
      Grammar::peso::value
      Grammar::peso::re

      Grammar::peso::ops

    )],

    xdeps=>1,
    subex=>qr{^throw_},

  );

# ---   *   ---   *   ---
# class attrs

  sub Frame_Vars($class) { return {

    -creg   => undef,
    -cclan  => 'non',
    -cproc  => undef,

    %{$PE_COMMON->Frame_Vars()},

  }};

# ---   *   ---   *   ---
# mach/file stuff

  Readonly our $PE_FLAGS=>{
    %{$PE_RE_FLAGS},

  };

  Readonly our $PE_SDEFS=>{

    VERSION => 'v0.00.1b',
    AUTHOR  => 'anon',
    ENTRY   => 'crux',

  };

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    # imports
    %{$PE_COMMON->get_retab()},
    %{$PE_VALUE->get_retab()},
    %{$PE_OPS->get_retab()},
    %{$PE_RE->get_retab()},

    # ^new
    q[hier-type]=>Lang::eiths(

      [qw(reg rom clan proc)],

      bwrap  => 1,
      insens => 1,

    ),

    q[io-type]=>Lang::eiths(

      [qw(io in out)],

      bwrap  => 1,
      insens => 1,

    ),

    q[wed-type]=>Lang::eiths(

      [qw(wed unwed)],

      bwrap  => 1,
      insens => 1,

    ),

    width=>Lang::eiths(

      [qw(

        byte wide brad word
        unit half line page

        nihil stark signal

      )],

      bwrap  => 1,
      insens => 1,

    ),

    spec=>Lang::eiths(

      [qw(ptr fptr str buf tab)],

      bwrap  => 1,
      insens => 1,

    ),

    branch => qr{
      (?<leaf> (.+))?
      (?: \\ \-* >)

    }x,

# ---   *   ---   *   ---

    q[sdef-name] => Lang::eiths(

      [keys %$PE_SDEFS],

      -insens => 1,
      -bwrap  => 1,

    ),

# ---   *   ---   *   ---
# switch cases

    q[on-key]  => Lang::insens('on',mkre=>1),
    q[or-key]  => Lang::insens('or',mkre=>1),
    q[off-key] => Lang::insens('off',mkre=>1),

# ---   *   ---   *   ---
# compile-time values

    q[def-key]   => Lang::insens('def',mkre=>1),
    q[undef-key] => Lang::insens('undef',mkre=>1),
    q[redef-key] => Lang::insens('redef',mkre=>1),

  };

# ---   *   ---   *   ---
# rule imports

  ext_rules(

    $PE_COMMON,qw(

    clist lcom
    term nterm opt-nterm

    beg-curly end-curly
    fbeg-parens fend-parens

  ));

  ext_rules(

    $PE_VALUE,qw(

    bare seal bare-list
    sigil flg flg-list
    num

    value vlist opt-vlist

  ));

  ext_rules(

    $PE_OPS,qw(

    expr opt-expr

  ));

  ext_rules($PE_RE,qw(re));

# ---   *   ---   *   ---
# pe file header

  rule('$<header> &rdhed sigil opt-nterm');

# ---   *   ---   *   ---
# placeholder for file header

sub rdhed($self,$branch) {
  my $mach=$self->{mach};
  my @path=$mach->{scope}->path();

};

# ---   *   ---   *   ---
# compile-time definitions

  rule('~<def-key> &discard');
  rule('~<redef-key> &discard');
  rule('~<undef-key> &discard');

  rule('$<def> &cdef def-key bare nterm');
  rule('$<redef> &credef redef-key bare nterm');
  rule('$<undef> &cundef undef-key bare nterm');

# ---   *   ---   *   ---
# ^post-parse

sub cdef($self,$branch) {

  $self->cdef_common($branch);

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $st    = $branch->bhash();

  $scope->cdef_decl($st->{nterm},$st->{bare});
  $scope->cdef_recache();

  $branch->clear();
  $branch->{value}=$st;

};

# ---   *   ---   *   ---
# ^move global to local scope

sub cdef_ctx($self,$branch) {

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $st    = $branch->{value};

  $scope->cdef_decl($st->{nterm},$st->{bare});
  $scope->cdef_recache();

};

# ---   *   ---   *   ---
# ^selfex

sub cdef_common($self,$branch) {
  my $key_lv=$branch->{leaves}->[0];
  $branch->pluck($key_lv);

};

# ---   *   ---   *   ---
# entry point for all hierarchicals

  rule('~<hier-type>');

  rule(q[

    $<hier>
    &hier_sort

    hier-type bare

  ]);

# ---   *   ---   *   ---
# preprocesses hierarchicals

sub hier_sort($self,$branch) {

  my ($type)=$branch->pluck(
    $branch->branch_in(qr{^hier\-type$})

  );

  $branch->{value}=$type->leaf_value(0);

  my $st=$branch->bhash();
  $branch->{-pest}=$st;

  $branch->clear();

};

# ---   *   ---   *   ---
# forks accto hierarchical type

sub hier_sort_ctx($self,$branch) {

  my $type = $branch->{value};
  my $ckey = q[-c].(lc $type);
  my $st   = $branch->{-pest};
  my $f    = $self->{frame};

  # set type of current scope
  $f->{$ckey}=$st->{bare};

  # get altered path
  my @cur=$self->cpath_change($type);
  @cur=$self->cpath() if ! @cur;

  # ^set path
  my $mach=$self->{mach};
  my @path=$mach->{scope}->path(@cur);

  # initialize scope
  $self->hier_nit($type);

  # parent nodes to this branch
  $self->hier_chld($branch,$type);

  # save pointer to branch
  # used for jumping later ;>
  @path=grep {$ARG ne '$DEF'} @path;
  $mach->{scope}->decl_branch($branch,@path);

};

# ---   *   ---   *   ---
# alters current path when
# stepping on a hierarchical

sub cpath_change($self,$type) {

  my @out = ();
  my $f   = $self->{frame};

  if($type eq 'ROM') {
    $f->{-creg}=undef;
    $f->{-cproc}=undef;

    @out=($f->{-cclan},$f->{-crom});

  } elsif($type eq 'REG') {
    $f->{-crom}=undef;
    $f->{-cproc}=undef;

    @out=($f->{-cclan},$f->{-creg});

  } elsif($type eq 'CLAN') {
    $f->{-creg}=undef;
    $f->{-crom}=undef;
    $f->{-cproc}=undef;

    @out=($f->{-cclan});

  };

  return @out;

};

# ---   *   ---   *   ---
# ^get current path from
# previously stepped hierarchicals

sub cpath($self) {

  my @out = ();
  my $f   = $self->{frame};

  if(defined $f->{-creg}) {
    @out=(
      $f->{-cclan},
      $f->{-creg},
      $f->{-cproc}

    );

  } elsif(defined $f->{-crom}) {
    @out=(
      $f->{-cclan},
      $f->{-crom},
      $f->{-cproc}

    );

  } else {
    @out=(
      $f->{-cclan},
      $f->{-cproc}

    );

  };

  return @out;

};

# ---   *   ---   *   ---
# get children nodes of a hierarchical
# performs parenting

sub hier_chld($self,$branch,$type) {

  # alter type for tree search
  if($type eq 'REG' || $type eq 'ROM') {
    $type=q[REG|ROM];

  };

  my @out=
    $branch->match_up_to(qr{^$type$});

  $branch->pushlv(@out);

  return @out;

};

# ---   *   ---   *   ---
# defaults out all flags for
# current scope

sub hier_nit($self,$type) {

  my $mach=$self->{mach};
  my @path=$mach->{scope}->path();

  # major scope properties
  if($type eq 'CLAN') {

    for my $key(keys %$PE_SDEFS) {
      my $value=$PE_SDEFS->{$key};
      $mach->{scope}->decl($value,@path,$key);

    };

  };

  # minor flags
  for my $key(keys %$PE_FLAGS) {
    my $value=$PE_FLAGS->{$key};
    $mach->{scope}->decl($value,@path,$key);

  };

  # match stacks
  if($type eq 'PROC') {

    $mach->{scope}->decl(
      {},@path,q[~:rematch]

    );

  };

};

# ---   *   ---   *   ---
# get currently looking at ROM sec

sub inside_ROM($self) {

  my $f=$self->{frame};

  return
      defined $f->{-crom}
  &&! defined $f->{-cproc}
  ;

};

# ---   *   ---   *   ---
# patterns for declaring members

  rule('~<width>');
  rule('~<spec>');
  rule('*<specs> &list_flatten spec');

  rule('$<type> width specs');

  # ^combo
  rule(q[

    $<ptr-decl>
    &ptr_decl

    type bare-list opt-vlist

  ]);

# ---   *   ---   *   ---
# pushes constructors to current namespace

sub ptr_decl($self,$branch) {

  my $st   = $branch->bhash(0,1,1);
  my $type = $st->{type}->bhash();

  # ^lis
  $branch->{value}={

    width  => $type->{width},

    names  => $st->{q[bare-list]},
    values => $st->{vlist},

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^pre-run step

sub ptr_decl_ctx($self,$branch) {

  my $mach   = $self->{mach};
  my @path   = $mach->{scope}->path();

  my $st     = $branch->{value};
  my $f      = $self->{frame};

  my @names  = @{$st->{names}};

  # errchk
  throw_invalid_scope(\@names,@path)
  if !$f->{-crom}
  && !$f->{-creg}
  && !$f->{-cproc}
  ;

  # enforce zero as default value
  for my $i(0..$#names) {
    $st->{values}->[$i]//=0;

  };

  $self->bind_decls($branch);

};

# ---   *   ---   *   ---
# ^errme

sub throw_invalid_scope($names,@path) {

  my $p=(@path) ? join q[/],@path : $NULLSTR;
  my $s=join q[,],map {$p.'/%s'} @$names;

  errout(

    q[No valid container for decls ]."<$s>",

    args => [@$names],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# register decls to current scope

sub bind_decls($self,$branch) {

  # data
  my $st     = $branch->{value};

  my @names  = @{$st->{names}};
  my @values = @{$st->{values}};

  # ctx
  my $f      = $self->{frame};
  my $mach   = $self->{mach};
  my $scope  = $mach->{scope};
  my @path   = $scope->path();

  # dst
  my $ptrs=[];

  # struct-wise macro expansion
  $scope->crepl(\$st);

  # iter
  while(@names && @values) {

    my $name  = shift @names;
    my $value = shift @values;

    # reparse element after macro expansion
    $self->value_expand(\$value);

    my $o={

      width => $st->{width},
      value => $value,

      const => $self->inside_ROM()

    };

    $scope->decl($o,@path,$name);
    push @$ptrs,$scope->rget(@path,$name);

  };

  $branch->{value}=$ptrs;

};

# ---   *   ---   *   ---
# in/out ctl

  rule('~<io-type>');
  rule('$<io> &rdio io-type ptr-decl');

# ---   *   ---   *   ---
# ^forks

sub rdio($self,$branch) {

  state $table={
    io  => undef,

    out => undef,
    in  => 'rdin',

  };

  my @lv    = @{$branch->{leaves}};
  my $class = $self->{frame}->{-class};

  my $st={
    type  => $lv[0]->leaf_value(0),
    value => $lv[1],

  };

  $branch->{value}=$st;
  $branch->clear_nproc();

  $branch->fork_chain(
    dom  => $class,
    name => $table->{$st->{type}},

  );

};

# ---   *   ---   *   ---
# ^proc input

sub rdin_opz($self,$branch) {

  my $st=$branch->{value};
  my $ar=$st->{value};

  $branch->{value}=$ar->{value};

};

sub rdin_run($self,$branch) {

  for my $ptr(@{$branch->{value}}) {
    $$ptr->{value}=$self->{mach}->stkpop();

  };

};

# ---   *   ---   *   ---
# soul of perl v2.0

  rule('$<vglob> beg-curly flg end-curly');

# ---   *   ---   *   ---
# aliasing

  rule('%<lis-key=lis>');
  rule('$<lis> lis-key vglob value');

# ---   *   ---   *   ---
# ^post-parse

sub lis($self,$branch) {

  my $st=$branch->bhash();
  $self->{Q}->add(sub {

    $branch->{value}={
      from => $st->{value},
      to   => $st->{vglob},

    };

    $branch->clear();

  });

};

# ---   *   ---   *   ---

sub vglob($self,$branch) {

  my @ar  = $branch->branch_values();
  my $out = $ar[1];

  $branch->clear();
  $branch->init($out);

};

# ---   *   ---   *   ---
# ^context build

sub lis_ctx($self,$branch) {

  my $st   = $branch->{value};

  my $mach = $self->{mach};
  my @path = $mach->{scope}->path();

  my $key  = $st->{to};
  $key     = "$key->{sigil}$key->{name}";

  $mach->{scope}->decl(
    $st->{from},
    @path,q[$LIS],$key

  );

};

# ---   *   ---   *   ---
# buffered IO

  rule('%<sow-key=sow>');
  rule('%<reap-key=reap>');

  rule('<sow> sow-key vglob vlist');
  rule('<reap> reap-key vglob');

# ---   *   ---   *   ---
# ^post-parse

sub sow($self,$branch) {

  my $lv=$branch->{leaves};
  my @ar=$lv->[1]->branch_values();

  $branch->{value}={

    fd => $lv->[1]->leaf_value(0),
    me => \@ar,

  };

  $branch->clear();

};

sub reap($self,$branch) {

  my $lv=$branch->{leaves};

  $branch->{value}=$lv->[1]->leaf_value(0);
  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind values

sub sow_opz($self,$branch) {

  my $st   = $branch->{value};
  my $mach = $self->{mach};
  my @path = $mach->{scope}->path();

  my $fd   = $st->{fd};

  $st->{fd}="$fd->{sigil}$fd->{name}";

  $self->array_vex(0,$st->{me},@path);
  $self->vex(0,\$st->{fd},@path);

  my ($fd2,$buff)=$mach->fd_solve(
    $st->{fd}->{raw}

  );

};

sub reap_opz($self,$branch) {

  my $mach = $self->{mach};
  my @path = $mach->{scope}->path();
  my $fd   = $branch->{value};

  $branch->{value}="$fd->{sigil}$fd->{name}";
  $self->vex(0,\$branch->{value},@path);

};

# ---   *   ---   *   ---
# ^exec

sub sow_run($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->{value};
  my $s    = $NULLSTR;

  my @path = $mach->{scope}->path();

  map {
    $s.=$self->deref($ARG)

  } @{$st->{me}};

  $mach->sow($st->{fd}->{raw},$s);

};

sub reap_run($self,$branch) {

  my $mach = $self->{mach};
  my $fh   = $branch->{value};

  $mach->reap($fh->{raw});

};

# ---   *   ---   *   ---
# for internal/out tree manipulation

  rule('~<branch>');
  rule('+<branches> branch vlist');

# ---   *   ---   *   ---
# ^post-parse

sub branches($self,$branch) {

  # get value list
  my $lv=$branch->{leaves};

  # BUG:
  #
  #   value sort refuses to trigger
  #   for strings in trees and i
  #   can't figure out why

  # ^this bit patches it out for now...
  if($lv->[1]->deepchk(1)) {
    $self->value_sort($lv->[1]);

  };

  my @values = $lv->[1]->branch_values();

  # get depth
  my $expr =  $branch->leaf_value(0);
     $expr =~ $REGEX->{branch};
  my $leaf = $+{leaf};

  # get dot count
  $leaf //=  $NULLSTR;
  $leaf   =~ s[\s+][]sxmg;

  my $lvl=length $leaf;

  $branch->clear();

  my $ar   = $branch->{ar};
     $ar //= [];

  push @$ar,{
    lvl   => $lvl,
    value => (@values > 1)
      ? \@values
      : $values[0]
      ,

  };

  $branch->{ar}=$ar;

};

# ---   *   ---   *   ---
# branch array

  rule('%<tree-key=tree>');
  rule('<tree> tree-key vglob branches');

# ---   *   ---   *   ---
# ^post-parse

sub tree($self,$branch) {

  # TODO:
  #
  #   function calls and derefs
  #   in tree decls; we have to
  #   look into expanding $VALUE
  #   itself...
  #
  #   or create different types of
  #   values, which i'd prefer ;>

  my $st    = $branch->bhash();
  my $exprs = $branch->branch_in(qr{^branches$});
  my $ar    = $exprs->{ar};

  $branch->{value}={
    vglob    => $st->{vglob},
    branches => $ar,

  };

  $branch->clear();2

};

sub tree_ctx($self,$branch) {

  my $st = $branch->{value};
  my $ar = $st->{branches};

  my $depth   = 0;
  my @anchors = ($branch);

  for my $ref(@$ar) {

    my ($lvl,$value)=(
      $ref->{lvl},
      $ref->{value}

    );

    my $anchor = $anchors[-1];
    my $prev   = $anchor->{leaves}->[-1];

    if($lvl > $depth) {
      push @anchors,$prev;
      $depth++;

    };

    while($lvl < $depth) {
      pop @anchors;
      $depth--;

    };

    $anchors[-1]->init($value);

  };

  $branch->{value}="$st->{vglob}->{name}";
  $branch->prich();

  exit;

};

# ---   *   ---   *   ---
# special definitions

  rule('~<sdef-name>');
  rule('$<sdef> sdef-name nterm');

# ---   *   ---   *   ---
# placeholder for special defs

sub sdef($self,$branch) {

  my $st=$branch->bhash(0,0);

  $branch->{value}={
    name  => $st->{q[sdef-name]},
    value => $st->{nterm},

  };

  $branch->clear();

};

sub sdef_ctx($self,$branch) {

  my $mach = $self->{mach};

  my $st   = $branch->{value};
  my @path = $mach->{scope}->path();

  if(uc $st->{name} eq 'ENTRY') {

    $st->{value}=[split
      $REGEX->{nsop},
      $st->{value}

    ];

  };

  my $o=$mach->{scope}->asg(

    $st->{value},

    @path,
    $st->{name}

  );

  $branch->{parent}->pluck($branch);

};

# ---   *   ---   *   ---
# switch flips

  rule('~<wed-type>');
  rule('$<wed> wed-type flg-list');

# ---   *   ---   *   ---
# ^handler

sub wed($self,$branch) {

  my $st=$branch->bhash(0,1);

  $branch->{value}={

    type  => uc $st->{q[wed-type]},
    flags => $st->{q[flg-list]},

  };

  $branch->clear();

};

sub wed_ctx($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->{value};
  my @path = $mach->{scope}->path();

  my $value=int($st->{type} eq 'WED');

  for my $f(@{$st->{flags}}) {

    my $fname=$f->{sigil} . $f->{name};

    $mach->{scope}->asg(
      $value,@path,$fname

    );

  };

};

# ---   *   ---   *   ---
# switches

  rule('~<on-key>');
  rule('~<or-key>');
  rule('~<off-key>');

  rule('$<on> on-key');
  rule('$<or> or-key');
  rule('$<off> off-key');

  rule('|<switch-type> &clip on or off');
  rule('$<switch> switch-type opt-expr');

# ---   *   ---   *   ---
# if

sub switch_on($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  $$nest++;
  $self->switch_case($branch);

};

sub switch_on_ctx($self,$branch) {
  $self->switch_sort($branch);

};

sub switch_on_pre($self,$branch) {
  $self->switch_case_pre($branch);

};

sub switch_on_ipret($self,$branch) {
  $self->switch_simplify($branch);

};

sub switch_on_run($self,$branch) {

  my $out=$self->opres($branch);

  $self->{c3}->jmp(
    $branch->next_branch()

  ) if ! $out;

};

# ---   *   ---   *   ---
# ^else/else if

sub switch_or($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  $self->switch_case($branch);

};

sub switch_or_ctx($self,$branch) {
  $self->switch_sort($branch);

};

sub switch_or_pre($self,$branch) {
  $self->switch_case_pre($branch);

};

sub switch_or_run($self,$branch) {

  my $out=($branch->{value}->{type} ne $NULL)
    ? $self->opres($branch)
    : 1
    ;

  $self->{c3}->jmp(
    $branch->next_branch()

  ) if ! $out;

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

      dom  => 'Grammar::peso',
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
  my $tree  = $st->{tree};
  my $type  = $st->{type};

  my $const = ($type eq 'value')
    ? $self->const_deref($st->{tree})
    : $self->opconst_flat($st->{tree})
    ;

  return $const;

};

# ---   *   ---   *   ---
# ^optimize out constant branches

sub switch_simplify($self,$branch) {

  my $cur   = 0;
  my $prev  = 0;

  my $ahead = $branch;

  return if ! $self->switch_const($branch);

my $i=0;
REPEAT:

  $cur  = $self->opres($ahead);
  $prev = ($cur &&! $prev);

  $ahead=($prev)
    ? $self->switch_flatten($ahead)
    : $self->switch_pluck($ahead)
    ;

  goto REPEAT if $ahead->{value} ne 'off';

};

# ---   *   ---   *   ---
# ^replace evaluation with
# branch leaves

sub switch_flatten($self,$branch) {

  my $ahead=$branch->next_branch();

  if($ahead->{value} ne 'off') {
    my $jmp=$branch->{leaves}->[-1];
    $branch->pluck($jmp);

  };

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
# end of switch

sub switch_off($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  $branch->clear();
  $self->switch_case($branch);

  $$nest--;

};

sub switch_off_cl($self,$branch) {
  $branch->clear();

};

# ---   *   ---   *   ---
# ^common to all

sub switch_case($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  $branch->init({
    lvl  => $$nest-1,
    type => $branch->{value},

  });

};

sub switch_case_pre($self,$branch) {

  my $lv=$branch->{leaves}->[0];
  my ($type,$tree);

  if(

     defined $lv
  && defined $lv->{leaves}->[0]

  ) {

    $type=$lv->{value};
    $tree=$lv->leaf_value(0);
    $branch->pluck($lv);

  } else {
    $type=$NULL;
    $tree=$NULL;

  };

  my $st={
    tree => $tree,
    type => $type,

  };

  $branch->{value}=$st;

};

# ---   *   ---   *   ---
# find next case in switch
# parent in-between nodes to branch

sub switch_sort($self,$branch) {

  state $re=qr{^(?:or|off)$}x;

  my $par    = $branch->{parent};
  my $anchor = $branch;

  my @lv     = ();
  my $helper = $branch->{leaves}->[1];
  my $lvl    = $helper->{value}->{lvl};

REPEAT:

  push @lv,$par->match_until(
    $anchor,$re,
    inclusive=>1

  );

  my $stop = pop @lv;
  my $idex = ($stop->{value} eq 'off')
    ? 0
    : 1
    ;

  my $st=$stop->leaf_value($idex);

  $anchor=$stop;
  goto REPEAT if $st->{lvl} != $lvl;

  $branch->pushlv(@lv);
  $self->switch_end($branch);

  $branch->pluck($helper);

};

# ---   *   ---   *   ---
# ^all others fork from here

sub switch($self,$branch) {

  my $lv  = $branch->{leaves}->[0];
  my $key = $lv->{value};

  $branch->pluck($lv);
  $branch->{value}=$key;

  $branch->fork_chain(
    dom  => $self->{frame}->{-class},
    name => "switch_${key}",

  );

};

# ---   *   ---   *   ---
# jump to node

sub jmp($self,$branch) {};

sub jmp_pre($self,$branch) {
  $branch->{value}=$branch->leaf_value(0);
  $branch->clear();

};

sub jmp_run($self,$branch) {
  $self->{c3}->jmp($branch->{value});

};

# ---   *   ---   *   ---

#sub match_ctx($self,$branch) {
#
#  my $mach       = $self->{mach};
#  my $st         = $branch->bhash();
#  my @path       = $mach->{scope}->path();
#
#  my $value      = $st->{value};
#
#  my ($o,$flags) = $self->re_vex($st->{nterm});
#  my $v          = $mach->{scope}->get(
#
#    @path,
#    $value->{raw}
#
#  );
#
#  $branch->{value}={
#
#    re  => $o,
#    v   => $v,
#
#    flg => $flags,
#
#  };
#
#  $branch->clear();
#
#};

## ---   *   ---   *   ---
## ^exec
#
#sub match_run($self,$branch) {
#
#  my $out  = 0;
#  my $st   = $branch->{value};
#
#  my $mach = $self->{mach};
#  my @path = $mach->{scope}->path();
#
#  my $v    = $st->{v}->{value};
#  my $re   = $st->{re};
#
#  # use/ignore whitespace
#  my $chk=($st->{flg}->{-sigws})
#    ? $v=~ m[$re]
#    : $v=~ m[$re]x
#    ;
#
#  # ^save matches
#  if($chk) {
#
#    my $match=$mach->{scope}->get(
#      @path,q[~:rematch]
#
#    );
#
#    for my $key(keys %-) {
#      $match->{$key}=$-{$key};
#
#    };
#
#    $out=1;
#
#  };
#
#  return $out;
#
#};

# ---   *   ---   *   ---
# pop current block

  rule('%<ret-key=ret>');
  rule('<ret> ret-key opt-nterm');

# ---   *   ---   *   ---

sub ret_ctx($self,$branch) {

  my $mach = $self->{mach};
  my $n    = 1;

  $mach->{scope}->ret($n);

};

# ---   *   ---   *   ---
# procedure calls

  rule('%<call-key=call>');
  rule('<call> call-key value vlist');

# ---   *   ---   *   ---
# ^post-parse

sub call($self,$branch) {

  my $st=$branch->bhash(0,1);
  $branch->clear();

  $branch->{value}={
    fn   => [(split $REGEX->{nsop},$st->{value})],
    args => $st->{values},

  };

};

# ---   *   ---   *   ---
# ^optimize

sub call_opz($self,$branch) {

  my $mach  = $self->{mach};
  my $st    = $branch->{value};

  my @path  = $mach->{scope}->path();
  my $procr = $mach->{scope}->search(

    (join q[::],@{$st->{fn}},q[$branch]),
    @path,

  );

  $st->{fn}=$$procr;

  for my $arg(@{$st->{args}}) {
    next if ! ($arg=~ m[^$REGEX->{bare}$]);
    $mach->{scope}->cderef(1,\$arg,@path);

  };

};

# ---   *   ---   *   ---
# ^exec

sub call_run($self,$branch) {

  my $st   = $branch->{value};

  my $fn   = $st->{fn};
  my @args = @{$st->{args}};

  for my $arg(reverse @args) {
    $self->{mach}->stkpush($arg);

  };

  unshift @{$self->{callstk}},
    $fn->shift_branch(keepx=>1);

};

# ---   *   ---   *   ---

#  Readonly our $FCALL=>{
#
#    name=>'fcall',
#    chld=>[
#      $MATCH
#
#    ],
#
#  };
#
#  Readonly our $FC_OR_V=>{
#
#    name => 'fc_or_v',
#
#    dom  => 'Grammar::peso',
#    fn   => 'fc_or_v',
#
#    chld => [Grammar::ralt(
#      $FCALL,$VALUE
#
#    )],
#
#  };
#
## ---   *   ---   *   ---
## wat
#
#sub fc_or_v($self,$branch) {
#
#  my $par=$branch->{parent};
#
#  for my $nd(@{$branch->{leaves}}) {
#    $branch->pluck($nd) if !$nd->{mfull};
#
#  };
#
#  my $type=$branch->{leaves}->[0]->{value};
#
#  if($type eq 'value') {
#    $branch=$branch->flatten_branch();
#
#  };
#
#  $branch=$branch->flatten_branch();
#  $branch->{value}='eval';
#
#};

# ---   *   ---   *   ---

#  Readonly our $COND_BEG=>{
#
#    name  => 'branch_beg',
#
#    dom   => 'Grammar::peso',
#    fn    => 'cond_beg',
#
#    chld  => [
#
#      {
#
#        name=>'nid',chld=>[{
#
#          fn   => 'capt',
#          name => Lang::eiths(
#
#            [qw(on or)],
#
#            brwap  => 1,
#            insens => 1,
#
#          ),
#
#        }],
#
#      },
#
#      $FC_OR_V
#
#    ],
#
#  };
#
## ---   *   ---   *   ---
#
#  Readonly our $IVCALL=>{
#
#    name => 'ivcall',
#    chld => [
#
#      $VLIST,
#      {name=>qr{\-\>\*}},
#
#      $VALUE,
#
#    ],
#
#  };
#
#  Readonly our $DEFCALL=>{
#
#    name => 'defcall',
#    chld => [
#
#      $VALUE,
#      $VLIST,
#
#    ],
#
#  };
#
## ---   *   ---   *   ---
#
#  Readonly our $FUCK=>{
#
#    name => 'fuck',
#    fn   => 'clip',
#
#    chld => [Grammar::ralt(
#      $IVCALL,$DEFCALL
#
#    )],
#
#  };
#
## ---   *   ---   *   ---
#
#  Readonly our $EXPR=>{
#
#    name => 'expr',
#
#    chld => [
#
#      {name=>qr[\{]},
#
#      $FUCK,
#
#      {name=>qr[\}]},
#
#    ],
#
#  };
#
## ---   *   ---   *   ---
#
#  Readonly our $TEST=>{
#
#    name  => 'test',
#
#    fn    => 'sxtest',
#    dom   => 'Grammar::peso',
#
#    chld => [Grammar::ralt(
#      $VLIST,$EXPR
#
#    )],
#
#  };
#
## ---   *   ---   *   ---
#
#sub sxtest($self,$branch) {
#  $branch->prich();
#
#};
#
## ---   *   ---   *   ---
#
#  Readonly our $COND_END=>{
#
#    name  => 'branch_end',
#
#    dom   => 'Grammar::peso',
##    fn    => 'cond_end',
#
#    chld  => [
#
#      {
#
#        name=>'nid',chld=>[{
#
#          fn   => 'capt',
#          name => Lang::eiths(
#
#            [qw(off)],
#
#            brwap  => 1,
#            insens => 1,
#
#          ),
#
#        }],
#
#      },
#
#    ],
#
#  };
#
## ---   *   ---   *   ---
#
#sub cond_beg_ctx($self,$branch) {
#
#  my $idex  = $branch->{idex};
#  my $depth = 0;
#
#  my @lv    = @{$branch->{parent}->{leaves}};
#  @lv       = @lv[$idex+1..$#lv];
#
#  $idex     = 0;
#
#  for my $nd(@lv) {
#
#    if($nd->{value} eq 'branch_end') {
#      $depth--;
#
#    } elsif($nd->{value} eq 'branch_beg') {
#      $depth++;
#
#    };
#
#    last if $depth<0;
#    $idex++;
#
#  };
#
#  @lv=@lv[0..$idex-1];
#  $branch->{-pest}=$branch->bhash();
#
#  $branch->pluck($branch->branches_in(
#    qr{^nid|eval$}
#
#  ));
#
#  $branch->pushlv(@lv);
#
#};
#
## ---   *   ---   *   ---
#
#sub cond_beg_run($self,$branch) {
#
#  my $st=$branch->{-pest};
#  my $ev=$st->{eval};
#
#  my $ok=0;
#
#  for my $nd(@{$ev->{leaves}}) {
#    $ok|=$nd->{chain}->[-1]->($self,$nd);
#
#  };
#
#  if(! $ok) {
#
#    my $callstk = $self->{callstk};
#    my $size    = @{$branch->{leaves}};
#
#    for(0..$size-1) {
#      shift @$callstk;
#
#    };
#
#  };
#
#};

# ---   *   ---   *   ---
# groups

  # default F
  rule('|<bltn> &clip sow reap');
  rule('|<cdef> &clip def redef undef');

  # non-terminated
  rule('|<meta> &clip lcom');

  # ^else
  rule(q[

    |<needs-term-list>
    &clip

    header hier sdef
    wed cdef lis

    re io ptr-decl
    switch
    bltn

  ]);

  rule(q[

    <needs-term>
    &clip

    needs-term-list term

  ]);

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(meta needs-term);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# test

  my $src=$ARGV[0];
  $src//='lps/peso.rom';

  my $prog=($src=~qr{\.rom$})
    ? orc($src)
    : $src
    ;

  return if ! $src;

  $prog =~ m[([\S\s]+)\s*STOP]x;
  $prog = ${^CAPTURE[0]};

  my $ice=Grammar::peso->parse($prog);

#  $ice->{p3}->prich();
#  $ice->{mach}->{scope}->prich();


  $ice->run(

    entry=>1,
    keepx=>1,

    input=>[

      '-hey',

    ],

  );

# ---   *   ---   *   ---
1; # ret
