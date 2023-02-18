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

  our $VERSION = v0.01.0;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,%O) {

  # defaults
  $O{fn}    //= $NOOP;
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
  $self->{opt}   = $O{opt};
  $self->{alt}   = $O{alt};
  $self->{greed} = $O{greed};
  $self->{max}   = $O{max};

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

  $dst->status_add($self) if $dst;
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

  $root->{ctx}=$ctx;

  my @anchors = ($root);
  my @pending = (@{$self->{leaves}});
  my $depth   = 0;

  push @{$ctx->{anchors}},\@anchors;
  push @{$ctx->{pending}},\@pending;

  # ^walk
  while(@pending) {

    $anchors[-1]->init_status($self);

    $self=$class->shift_pending(
      $ctx,\$depth

    ) or next;

    ! $self->alternation(
      $ctx,\$s

    ) or next;

    ! $self->greed($ctx,\$s) or next;

    my $m  = $self->re_or_branch($ctx,\$s);
    my $fn = $self->{fn};

    $m->{other}=$self;

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
# ^skips non-node steps in
# the walk array

sub shift_pending($class,$ctx,$depthr) {

  my $out=shift @{$ctx->{pending}->[-1]};
  my $ans=$ctx->{anchors}->[-1];

  if(! $class->is_valid($out)) {

    while($out <= $$depthr) {

      pop @$ans;
      $$depthr--;

    }

    $out=undef;

  };

  return $out;

};

# ---   *   ---   *   ---
# branch must match at most one
# pattern out of a group

sub alternation($self,$ctx,$sref) {

  my $out=0;
  my $alt=$self->has_flag('alt');

  my $anchors = $ctx->{anchors}->[-1];
  my $root    = $anchors->[0];

  if($alt && $alt eq $self) {

    my ($m,$ds)=$self->hier_match($ctx,$$sref);

    if($m) {
      $$sref=$ds;

      $root->pushlv($m);
      $root->status_add($self);

    };

    $out=1;

  };

  return $out;

};

# ---   *   ---   *   ---
# branch keeps matching until
# failure

sub greed($self,$ctx,$sref) {

  my $greed   = $self->has_flag('greed');
  my $out     = undef;

  my $anchors = $ctx->{anchors}->[-1];
  my $root    = $anchors->[-1];

  while($greed && $greed eq $self) {

    $out//=1;

    my ($m,$ds) = $self->match($ctx,$$sref);
    my $status  = $m->{status};

    my $clip    = $root eq $anchors->[-1];

    if($status->{total} && $m->status_ok()) {

      $$sref=$ds;

      $m=(! $clip)
        ? $m->{leaves}
        : [$m]
        ;

      $root->pushlv(@$m);
      $root=$m->[0] if $clip;

      $root->status_add($self,1);

      $out++;

    } else {
      $root->{status}->{total}--;
      last;

    };

  };

  return $out;

};

# ---   *   ---   *   ---
# inits 'completion bar' ;>

sub init_status($self,$other) {

  return {}

  if ! $other
  || $self->{value} ne $other->{value}
  ;

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

  };

  return $self->{status};

};

# ---   *   ---   *   ---
# details matches within a branch

sub status_array($self) {

  my $out=[];

  for my $nd(@{$self->{leaves}}) {

    my $sub_status={

      alt => $nd->{alt},
      opt => $nd->{opt},

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
# ^get match success

sub status_ok($self) {

  $self->status_chk();

  my $status = $self->{status};
  my $subok  = $self->status_subok();

  my $opt    = $status->{opt};
  my $alt    = $status->{alt};
  my $max    = $status->{max};
  my $ar     = $status->{ar};

  my $ok=int(

     ($subok eq @$ar)
  || ($max && $subok <= $max)
  || ($alt && $subok eq 1)
  || ($opt)

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

  for my $sub_status(@$ar) {

    $out+=

       $sub_status->{ok}
    || $sub_status->{opt}
    ;

  };

  return $out;

};

# ---   *   ---   *   ---
# ^recurse

sub status_chk($self) {

  my $status  = $self->{status};
  my @pending = @{$self->{leaves}};

  $status->{total}=0;

  my $i  = 0;
  my $ar = $status->{ar};

  for my $nd(@pending) {

    next if ! $nd->{status};

    my $sub_status=$ar->[$i++];
    $sub_status->{ok}=$nd->status_ok();

  };

};

# ---   *   ---   *   ---
# force failure

sub status_ffail($self) {

  my $status=$self->{status};
  $status->{fail}=1;

};

# ---   *   ---   *   ---
# match against all branches

sub hier_match($self,$ctx,$s) {

  my @out=(undef,$s);

  for my $branch(@{$self->{leaves}}) {

    my ($m,$ds)=$branch->match($ctx,$s);

    if($m->status_ok()) {

      @out=($m,$ds);

      $ctx->{Q}->wex();
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

