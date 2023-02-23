#!/usr/bin/perl
# ---   *   ---   *   ---
# Grammar
# Halfway mimics p6's
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Tree::Grammar;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::IO;

  use parent 'Tree';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,%O) {

  # defaults
  $O{fn}    //= $NOOP;
  $O{hier}  //= 0;
  $O{opt}   //= 0;
  $O{alt}   //= 0;
  $O{greed} //= 0;
  $O{max}   //= 0;

  # get instance
  my $self=Tree::nit(

    $class,
    $frame,

    $O{parent},
    $O{value},

    %O

  );

# ---   *   ---   *   ---
# setup post-match actions

  $self->{fn}    = $O{fn};
  $self->{hier}  = $O{hier};
  $self->{opt}   = $O{opt};
  $self->{alt}   = $O{alt};
  $self->{greed} = $O{greed};
  $self->{max}   = $O{max};

  $self->{chain} = $O{chain};

  if(

     $self->{parent}
  && $self->{parent}->has_flag('alt')

  ) {$self->{hier}=1};

  return $self;

};

# ---   *   ---   *   ---
# ^from instance

sub init($self,$x,%O) {

  $O{parent}//=$self;

  return $self->{frame}->nit(value=>$x,%O);

};

# ---   *   ---   *   ---
# clones a node

sub dup($self) {

  my $out     = undef;

  my @anchor  = ();
  my @pending = ($self);

  while(@pending) {

    my $nd=shift @pending;

    my $cpy=$nd->{frame}->init(

      value  => $nd->{value},
      fn     => $nd->{fn},
      opt    => $nd->{opt},
      greed  => $nd->{greed},
      max    => $nd->{max},
      alt    => $nd->{alt},
      chain  => $nd->{chain},

      parent => (@anchor)
        ? (shift @anchor)
        : $out
        ,

    );

    $out//=$cpy;

    unshift @anchor,$cpy;
    unshift @pending,@{$nd->{leaves}};

  };

  return $out;

};

# ---   *   ---   *   ---
# remove branch if it's not root

sub purge($self) {
  $self->{parent}->pluck($self)
  if $self->{parent};

};

# ---   *   ---   *   ---
# get next fn in queue

sub shift_chain($self,@chain) {

  # default to old
  $self->{chain}//=[];
  @chain=@{$self->{chain}}
  if !@chain;

  $self->{fn}    = undef;
  $self->{chain} = \@chain;

  $self->{fn}=shift @{
    $self->{chain}

  };

  $self->{fn}//=$NOOP;

};

# ---   *   ---   *   ---
# ^whole branch, no reasg

sub shift_branch($self,%O) {

  # defaults
  $O{keepx}//=0;

  my @out     = ();
  my @pending = ($self);

  while(@pending) {

    my $nd=shift @pending;

    push @out,[$nd,$nd->{fn}]
    if $nd->{fn} ne $NOOP;

    $nd->shift_chain() if !$O{keepx};

    unshift @pending,@{$nd->{leaves}};

  };

  return @out;

};

# ---   *   ---   *   ---
# true if node is part of
# a branch with a given flag

sub branch_has_flag($self,$flag) {

  my $out=($self->{$flag})
    ? $self
    : undef
    ;

  while(defined $self->{parent}) {

    if($self->{$flag}) {
      $out=$self;
      last;

    };

    $self=$self->{parent};

  };

  return $out;

};

# ---   *   ---   *   ---
# ^had by self

sub has_flag($self,$flag) {
  return $self->{$flag};

};

# ---   *   ---   *   ---
# exec calls attached to branch

sub on_match($self,$branch) {

  my ($root)=$branch->root();

  $self->{fn}->($root->{ctx},$branch)
  if $self->{fn} ne $NOOP;

  $branch->shift_chain(@{$self->{chain}});

};

# ---   *   ---   *   ---
# run string match

sub re_leaf($self,$anchor,$sref) {

  my $out = undef;
  my $re  = $self->{value};

  if($$sref =~ s[^\s*($re)\s*][]) {
    $out=$anchor->init($1);

  } elsif(! $self->{opt}) {
    $anchor->status_ffail();

  };

  return $out;

};

# ---   *   ---   *   ---
# determines type of node

sub re_or_branch($self,$ctx,$sref) {

  my $out = undef;
  my $x   = $self->{value};

  my $anchors = $ctx->{anchors}->[-1];
  my $anchor  = $anchors->[-1];

  my $dst     = undef;

  if(is_qre($x)) {
    $out=$self->re_leaf($anchor,$sref);
    $dst=$anchor if $out;

  } else {
    $out=$anchor->init($self->{value});
    push @$anchors,$out;

  };

  return ($out,$dst);

};

# ---   *   ---   *   ---
# recurse

sub match($self,$ctx,$s) {

  my $x     = $self->{value};
  my $fn    = $self->{fn};

  my $class = $self->{frame}->{-class};

  # parallel
  my $root=$self->{frame}->nit(
    parent => undef,
    value  => $x,

  );

  $root->{ctx}=$ctx;
  $root->init_status($self);

  my @anchors = ($root);
  my @pending = (@{$self->{leaves}});
  my $depth   = 0;

  my $branch  = $self;

  push @{$ctx->{anchors}},\@anchors;
  push @{$ctx->{pending}},\@pending;

  # ^walk
  while(@pending) {

    last if ! length $s;

    $self=$branch->shift_pending(
      $ctx,\$depth

    ) or next;

    my ($m,$dst) = $self->re_or_branch($ctx,\$s);
    my $fn       = $self->{fn};

    $anchors[-1]->init_status($self);
    $dst->status_add($self) if $dst;

    my $altr=$self->alternation($ctx,\$s);

    if($altr) {
      next;

    };

    ! $self->greed($ctx,\$s) or next;
    ! $self->hier_sub($ctx,\$s) or next;

    if($class->is_valid($m)) {
      $m->{other}=$self;
      $fn->($ctx,$m) if $fn ne $NOOP;

    } elsif(! $m && ! $self->{opt}) {
      last;

    };

    my @lv=@{$self->{leaves}};
    $depth+=0<@lv;

    unshift @pending,@lv,$depth;

  };

#$root->prich();
#say "_____________________\n";

  pop @{$ctx->{anchors}};
  pop @{$ctx->{pending}};

  return ($root,$s);

};

# ---   *   ---   *   ---
# ^skips non-node steps in
# the walk array

sub shift_pending($branch,$ctx,$depthr) {

  my $pending = $ctx->{pending}->[-1];
  my $anchors = $ctx->{anchors}->[-1];
  my $anchor  = $anchors->[-1];

  my $total   = int(@{$branch->{leaves}});
  my $current = int(@$pending);

  my $out     = shift @$pending;
  my $class   = $branch->{frame}->{-class};

  if(! $class->is_valid($out)) {

    while($out <= $$depthr) {
      pop @$anchors;
      $$depthr--;

    };

    $out=undef;

  };

  # end of alternation
  my $eoa=int($branch->{alt}

  && ! $$depthr
  && ! ($total eq $current)

  );

  if($eoa) {

    if($ctx->{match_ok}) {
      @$pending = ();
      $out      = undef;

    } else {
      $anchor->clear_branches();

    };

  };

  $out=(! @$anchors) ? undef : $out;

  return $out;

};

# ---   *   ---   *   ---
# wrap parens round branch

sub subtree($self,$ctx,$sref,%O) {

  # defaults
  $O{-root}//=0;
  $O{-clip}//=0;

  my $anchors = $ctx->{anchors}->[-1];
  my $root    = $anchors->[$O{-root}];

  return undef if ! $root;

  my $out=undef;

  my ($m,$ds)=$self->hier_match(
    $ctx,$$sref,-closed=>1

  );

  my $match;

  if($O{-clip}) {
    $match=$self->subtree_clip(
      $root,$m,$ds,$sref

    );

    $out=pop @$anchors;

  } else {
    $match=$self->subtree_noclip(
      $root,$m,$ds,$sref

    );

    pop @$anchors;
    $out=$match;

  };

  $ctx->{match_ok}=defined $match;

  return $out;

};

# ---   *   ---   *   ---
# ^common subtree solve

sub subtree_noclip($self,$root,$m,$ds,$sref) {

  my $out=undef;

  if($m && $m->status_ok()) {
    $$sref=$ds;

    $root->pushlv($m);
    $root->flatten_branch();

    $root->status_add($self);

    $out=$root;

  } elsif($self->{opt}) {
    say "NOCLIP OPT-FAIL NOT IMPLEMENTED";
    exit;

  };

  return $out;

};

# ---   *   ---   *   ---
# ^mess of an edge-case

sub subtree_clip($self,$root,$m,$ds,$sref) {

  my $out     = undef;
  my $clip    = 1 <= @{$root->{leaves}};

  if($m && $m->status_ok()) {

    $$sref = $ds;
    my @lv = ($m);

    if($clip) {

      $root = $root->{leaves}->[-1];
      $root = $root->{leaves}->[0];

      @lv   = @{$m->{leaves}};

    };

    $root->pushlv(@lv);
    $root->status_add($self);

    $out=$m;

  } elsif($self->{opt}) {
    $root->status_force_ok();

  };

  return $out;

};

# ---   *   ---   *   ---
# branch opens a new scope

sub hier_sub($self,$ctx,$sref) {

  my $out=0;

  if($self->has_flag('hier')) {

    my $nd=$self->subtree(
      $ctx,$sref,

      -root=>-1

    );

    $out=1;

  };

  return $out;

};

# ---   *   ---   *   ---
# branch must match at most one
# pattern out of a group

sub alternation($self,$ctx,$sref) {

  my $out=0;

  if($self->has_flag('alt')) {

    my $n=$self->subtree(
      $ctx,$sref,

      -root=>-1,

    );

    $out=1;

  };

  return $out;

};

# ---   *   ---   *   ---
# branch keeps matching until
# failure

sub greed($self,$ctx,$sref) {

  my $out  = 0;
  my $root = undef;

  if($self->has_flag('greed')) {
    $out=1;

    while(1) {

      my $t=$self->subtree(

        $ctx,$sref,

        -root=>-1,
        -clip=>1,

      );

      if($t && $t->status_ok()) {
        $root//=$t;
        $out++;

      } else {
        $root->flatten_branch() if $root;
        last;

      };

    };

  };

  return $out;

};

# ---   *   ---   *   ---
# inits 'completion bar' ;>

sub init_status($self,$other) {

  return if exists $self->{status};

  my @lv_s = @{$self->{leaves}};
  my @lv_o = @{$other->{leaves}};

  my $ar   = $other->status_array();
  my $max  = $other->{max};

  $self->{status}={

    ar    => $ar,
    max   => $max,

    fail  => 0,

    opt   => int($other->{opt} && ! $max),
    alt   => $other->{alt},
    greed => $other->{greed},

  };

  return $self->{status};

};

# ---   *   ---   *   ---
# details matches within a branch

sub status_array($self) {

  my $out=[];

  for my $nd(@{$self->{leaves}}) {

    my $sub_status={

      alt   => $nd->{alt},
      opt   => $nd->{opt},
      greed => $nd->{greed},

      ok  => 0,

    };

    push @$out,$sub_status;

  };

  return $out;

};

# ---   *   ---   *   ---
# register succesful match

sub status_add($self,$other) {

  my $status = $self->{status};

  my $ar     = $status->{ar};
  my $idex   = $other->{idex};

  $ar->[$idex]->{ok}=1;

};

# ---   *   ---   *   ---
# ^force success

sub status_force_ok($self) {

  my $status  = $self->{status};
  my $ar      = $status->{ar};

  # walk tree and set bools
  map {$ARG->{ok}=1} @$ar;
  map {

    $ARG->status_force_ok()
    if $ARG->{status};

  } @{$self->{leaves}};

  # set bool for self
  $status->{fail}=0;

};

# ---   *   ---   *   ---
# get match success

sub status_ok($self) {

  $self->status_chk();

  my $status = $self->{status};
  my $subok  = $self->status_subok();

  my $opt    = $status->{opt};
  my $alt    = $status->{alt};
  my $greed  = $status->{greed};
  my $max    = $status->{max};
  my $ar     = $status->{ar};

  my $ok=int(

     ($subok eq @$ar)
  || ($max && $subok <= $max)
  || ($alt && $subok eq 1)
  || ($opt && ! $greed)

  );

  $status->{fail}=int(
     (! $ok) || ($status->{fail})

  );

  return ! $status->{fail};

};

# ---   *   ---   *   ---
# ^walk children

sub status_subok($self) {

  my $out    = 0;

  my $status = $self->{status};
  my $ar     = $status->{ar};

  for my $sus(@$ar) {

    $out+=

       $sus->{ok}
    || ($sus->{opt} && ! $sus->{greed})
    ;

  };

  return $out;

};

# ---   *   ---   *   ---
# ^recurse

sub status_chk($self) {

  my $status  = $self->{status};
  my @pending = @{$self->{leaves}};

  my $i  = 0;
  my $ar = $status->{ar};

  for my $nd(@pending) {

    next if ! $nd->{status};

    my $sus    = $ar->[$i++];
    $sus->{ok} = $nd->status_ok();

  };

};

# ---   *   ---   *   ---
# force failure

sub status_ffail($self) {

  my $status=$self->{status};
  $status->{fail}=1;

};

# ---   *   ---   *   ---
# debug print

sub status_db_out($self) {

  my @out    = ();

  my $status = $self->{status};
  my $ar     = $status->{ar};

  my $i=0;
  for my $sub_status(@$ar) {

    push @out,int(

       $sub_status->{ok}
    || $sub_status->{opt}

    );

  };

  $i=0;
  say int(! $status->{fail}) . " $self->{value}";
  for my $ok(@out) {

    say "\\-->$ok";
    $i++;

  };

  say $NULLSTR;

  for my $leaf(@{$self->{leaves}}) {
    next if ! $leaf->{status};
    $leaf->status_db_out();

  };

};

# ---   *   ---   *   ---
# match against all branches

sub hier_match($self,$ctx,$s,%O) {

state $d_depth=undef;
$d_depth//=-1;
$d_depth++;

my $s_depth=('.  ' x $d_depth) . '\-->';

  # defaults
  $O{-closed}//=0;

  my @out=(undef,$s);
  my @pending=($O{-closed})
    ? $self
    : @{$self->{leaves}}
    ;

  for my $branch(@pending) {
say "\n${s_depth}TRY $branch->{value}";

    my ($m,$ds)=$branch->match($ctx,$s);

    if($m->status_ok()) {

      @out=($m,$ds);

      $ctx->{Q}->wex();
      $branch->on_match($m);

say "${s_depth}GOT $branch->{value}";

      last;

    } else {
say "${s_depth}NGT $branch->{value}";
#$m->prich();
#$m->status_db_out();

    };

  };

say "${s_depth}RET\n";
$d_depth--;

  return @out;

};

# ---   *   ---   *   ---
# makes new dst for parser ice

sub new_p3($self,$ctx) {

  my $p3=$self->{frame}->nit(
    parent => undef,
    value  => $self->{value}

  );

  $p3->{ctx}=$ctx;

  return $p3;

};

# ---   *   ---   *   ---
# ^breaks down input

sub parse($self,$s) {

  my $ctx  = $self->{ctx};
  my $gram = $ctx->{gram};

  while(1) {

    my ($match,$ds)=$gram->hier_match($ctx,$s);

    $self->throw_no_match($gram,$s)
    if ! $match;

    # push to tree and run queue
    $self->pushlv($match);
    $ctx->{Q}->wex();

    # update string
    $s=$ds;

    # ^exit when input consumed
    last if ! length $s;

  };

};

# ---   *   ---   *   ---
# ^errme

sub throw_no_match($self,$gram,$s) {

  my $s_short=substr $s,0,64;

  say {*STDERR}

    "_______________\n\n" .

    "PARSE-IRUPT"

  ;

  $self->prich(errout=>1);

  say {*STDERR} "_______________\n";

  errout(

    "%s\n\n".
    q[^^^ Could not parse this bit ].
    q[with grammar <%s>],

    args => [$s_short,$gram->{value}],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
1; # ret

