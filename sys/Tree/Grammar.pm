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

  our $VERSION = v0.00.8;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,%O) {

  # defaults
  $O{fn}    //= $NOOP;
  $O{opt}   //= 0;
  $O{alt}   //= 0;
  $O{greed} //= 0;

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
  $self->{opt}   = $O{opt};
  $self->{alt}   = $O{alt};
  $self->{greed} = $O{greed};

  $self->{chain} = $O{chain};

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

sub has_flag($self,$flag) {

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
# turns trees with the structure:
#
# ($match)
# \-->subtype
# .  \-->value
#
# into:
#
# ($match)
# \-->value

sub list_flatten($ctx,@branches) {

  for my $branch(@branches) {

    for my $nd(@{$branch->{leaves}}) {
      $nd->flatten_branch();

    };

  };

};

# ---   *   ---   *   ---
# rewind the tree match

sub rew($ctx,$st) {

  unshift @{$st->{pending}},@{
    $st->{nd}->{parent}->{leaves}

  };

};

# ---   *   ---   *   ---
# saves capture to current container

sub capt($ctx,$branch) {

  my $anchors = $ctx->{anchors}->[-1];
  my $anchor  = $anchors->[-1];

#  $anchor->init($branch->{value});

};

# ---   *   ---   *   ---
# ^both capt and rew

sub crew($ctx,$st) {

  capt($st);
  rew($st);

};

# ---   *   ---   *   ---
# terminates an expression

sub term($ctx,$branch) {
  $branch->{parent}->pluck($branch);
  @{$ctx->{pending}->[-1]}=();

};

# ---   *   ---   *   ---
# removes branch

sub discard($ctx,$match) {
  my ($root)=$match->root();
  $root->pluck($match);

};

# ---   *   ---   *   ---
# replace branch with it's children

sub clip($ctx,$match) {

  if( ! $match->{parent}) {
    my @lv=@{$match->{leaves}};
    map {$ARG->flatten_branch()} @lv;

  } else {
    $match->flatten_branch();

  };

};

# ---   *   ---   *   ---
# exec calls attached to branch

sub on_match($self,$match) {

  my ($root)=$self->root();

  $self->{fn}->($root->{ctx},$match)
  if $self->{fn} ne $NOOP;

  $match->shift_chain(@{$self->{chain}});

};

# ---   *   ---   *   ---
# run string match

sub re_leaf($self,$anchor,$sref) {

  my $out = undef;
  my $re  = $self->{value};

  if($$sref =~ s[^\s*($re)\s*][]) {
    $out=$anchor->init($1);

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

  if(is_qre($x)) {
    $out=$self->re_leaf($anchor,$sref);

  } else {
    $out=$anchor->init($self->{value});
    push @$anchors,$out;

  };

  $anchor->{status}->{total}+=defined $out;
  return $out;

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

  my $status  = $root->init_status($self);

  my @anchors = ($root);
  my @pending = (@{$self->{leaves}});
  my $depth   = 0;

  push @{$ctx->{anchors}},\@anchors;
  push @{$ctx->{pending}},\@pending;

  # ^walk
  while(@pending) {

    $self=$class->shift_pending(
      $ctx,\$depth

    ) or next;

    my $alt=$self->has_flag('alt');

    if($alt && $alt eq $self) {

      my ($m,$ds)=$self->hier_match($ctx,$s);

      if($m) {
        $s=$ds;
        $root->pushlv($m);
        $root->{status}->{total}++;

      };

      next;

    };

    my $m  = $self->re_or_branch($ctx,\$s);
    my $fn = $self->{fn};

    $fn->($ctx,$m) if $m && $fn ne $NOOP;

    my @lv=@{$self->{leaves}};
    $depth+=0<@lv;

    unshift @pending,@lv,$depth;

  };

  pop @{$ctx->{anchors}};
  pop @{$ctx->{pending}};

  return ($root,$s);

};

# ---   *   ---   *   ---
# ^inits 'completion bar' ;>

sub init_status($self,$other) {

  my $root     = $self;

  my @pending  = ($self);
  my @parallel = ($other);

  while(@pending && @parallel) {

    $self    = shift @pending;
    $other   = shift @parallel;

    my @lv_s = @{$self->{leaves}};
    my @lv_o = @{$other->{leaves}};

    my $min  = int(grep {! $ARG->{opt}} @lv_o);
    my $max  =
      0 + $other->{alt} + $other->{greed}*2;

    $self->{status}={

      min   => $min,
      max   => $max,

      total => 0,
      fail  => 0,

    };

    unshift @pending,@lv_s;
    unshift @parallel,@lv_o;

  };

  return $root->{status};

};

# ---   *   ---   *   ---
# ^get match success

sub status_ok($self) {

  my $status = $self->{status};

  my $max    = $status->{max};
  my $min    = $status->{min};
  my $total  = $status->{total};

  $status->{fail}=int($total < $min);

  return ! $status->{fail};

};

# ---   *   ---   *   ---
# ^skips non-node steps in
# the walk array

sub shift_pending($class,$ctx,$depthr) {

  my $out=shift @{$ctx->{pending}->[-1]};
  my $ans=$ctx->{anchors}->[-1];

  if(! $class->is_valid($out)) {

    while($out < $$depthr) {
      pop @$ans;
      $$depthr--;

    }

    $out=undef;

  };

  return $out;

};

# ---   *   ---   *   ---
# match against all branches

sub hier_match($self,$ctx,$s) {

  my @out=(undef,$s);

  for my $branch(@{$self->{leaves}}) {

    my ($m,$ds)=$branch->match($ctx,$s);

    if($m->status_ok()) {
      @out=($m,$ds);
      $branch->on_match($m);

      last;

    };

  };

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

    throw_no_match($gram,$s)
    if ! $match;

    # push to tree && update string
    $self->pushlv($match);
    $s=$ds;

    # ^exit when input consumed
    last if ! length $s;

  };

};

# ---   *   ---   *   ---
# ^errme

sub throw_no_match($self,$s) {

  my $s_short=substr $s,0,64;

  errout(

    "%s\n\n".
    q[^^^ Could not parse this bit ].
    q[with grammar <%s>],

    args => [$s_short,$self->{value}],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
1; # ret

