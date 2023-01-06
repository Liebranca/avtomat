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

  our $VERSION = v0.00.6;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,%O) {

  # defaults
  $O{fn}    //= $NOOP;
  $O{opt}   //= 0;
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
# true if node is part of an
# optional branch

sub opt_branch($self) {

  my $out=0;

  while(defined $self->{parent}) {

    if($self->{opt}) {
      $out=1;
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

sub list_flatten($match) {

  for my $branch(@{$match->{leaves}}) {
    $branch->flatten_branch();

  };

};

# ---   *   ---   *   ---
# ^a more complex form of that

sub nest_flatten($match,$pat) {

  for my $branch(
    $match->branches_in(qr{^$pat$})

  ) {

    list_flatten($branch);
    $branch->flatten_branch();

  };

};

# ---   *   ---   *   ---
# rewind the tree match

sub rew($st) {

  unshift @{$st->{pending}},@{
    $st->{nd}->{parent}->{leaves}

  };

};

# ---   *   ---   *   ---
# saves capture to current container

sub capt($st) {
  $st->{anchor}->init($st->{capt});

};

# ---   *   ---   *   ---
# ^both capt and rew

sub crew($st) {

  capt($st);
  rew($st);

};

# ---   *   ---   *   ---
# terminates an expression

sub term($st) {

  $st->{anchor}     = $st->{nd}->walkup();
  @{$st->{pending}} = ();

};

# ---   *   ---   *   ---
# removes branch

sub discard($match) {
  my ($root)=$match->root();
  $root->pluck($match);

};

# ---   *   ---   *   ---
# makes helper for match

sub match_st($self,$sref) {

  my $frame = Tree::Grammar->get_frame();
  my $root  = $frame->nit(

    parent => undef,
    value  => $self->{value}

  );

# ---   *   ---   *   ---

  my $st=bless {

    sref    => $sref,

    root    => $root,
    anchor  => $root,

    an      => [],

    capt    => q[],
    nd      => undef,

    frame   => $frame,
    pending => [@{$self->{leaves}}],

    matches => [0],
    mint    => [0],

    full    => 0,
    fmint   => 0,
    mlast   => 0,

    re      => undef,
    key     => undef,

    kls     => $self->{value},
    fn      => [],
    opts    => [],

    tk      => [[]],

  },'Tree::Grammar::Matcher';

  return $st;

};

# ---   *   ---   *   ---
# parse failure errme

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
# decon string by walking tree branch

sub match($self,$s) {

  my $st   = $self->match_st(\$s);
  my $fail = 0;

  while(@{$st->{pending}}) {

#    last if !length $s;

    if(!$st->get_next()) {

      $st->branch_fn();
      $st->pop_anchor();

      next;

    };

    my @tail=@{$st->{nd}->{leaves}};
    push @tail,0 if @tail;

    $st->attempt();
    unshift @{$st->{pending}},@tail;

  };

  while(@{$st->{fn}}) {
    $st->branch_fn();

  };

  $st->{full}  = $st->{matches}->[0];
  $st->{fmint} = $st->{mint}->[0];

  $fail|=

       $st->{full} == 0
    || $st->{full} != $st->{fmint}

  ;

  my $out=($fail)
    ? $NULL
    : $st->{root}
    ;

  return ($out,$s);

};

# ---   *   ---   *   ---
# attempt match against all possible
# branches of a grammar

sub parse($self,$ctx,$s) {

  my $frame = Tree::Grammar->get_frame();

  my $tree  = $frame->nit(
    parent => undef,
    value  => $self->{value}

  );

#:!;> OHCRAP
#:!;>
#:!;> storing a reference to the object that
#:!;> spawned this tree, within the tree
#:!;>
#:!;> frankly quite terrible and an outright
#:!;> dependency loop.
#:!;>
#:!;> but it works.

  $tree->{ctx}=$ctx;

  while(1) {

    my $matched=0;

    # test each branch against string
    for my $branch(@{$self->{leaves}}) {

      my ($match,$ds)=$branch->match($s);

      # update string and append
      # to tree on succesful match
      if($match ne $NULL) {

        $tree->pushlv($match);

        $branch->{fn}->($match)
        if $branch->{fn} ne $NOOP;

        my @chain=(@{$branch->{chain}});
        $match->shift_chain(@chain);

        $s=$ds;
        $matched|=1;

        last;

      };

    };

    $self->throw_no_match($s)
    if !$matched;

    last if !length $s;

  };

  return $tree;

};

# ---   *   ---   *   ---
# helper methods

package Tree::Grammar::Matcher;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

# ---   *   ---   *   ---

sub get_next($self) {

  $self->{nd}  = shift @{$self->{pending}};
  goto TAIL if !$self->{nd};

  $self->{key} =
  $self->{re}  = $self->{nd}->{value}
  ;

  $self->{re}  = undef if !is_qre($self->{re});
  $self->{key} = undef if defined $self->{re};

TAIL:
  return $self->{nd};

};

# ---   *   ---   *   ---

sub attempt($self) {

  if($self->{re}) {
    $self->attempt_match();

  } elsif($self->{key}) {
    $self->expand_tree();

  };

};

# ---   *   ---   *   ---
# current node has a coderef

sub has_action($self) {

  return

     defined $self->{nd}->{fn}
  && $self->{nd}->{fn} ne $NOOP
  ;

};

# ---   *   ---   *   ---

sub attempt_match($self) {

  my $re        = $self->{re};
  $self->{capt} = undef;

  $self->{mint}->[-1]+=
    !$self->{nd}->{opt};

# ---   *   ---   *   ---

  if(${$self->{sref}}=~
    s[^(\s*($re)\s*)][]x

  ) {

    $self->{mlast}=1;
    $self->{capt}=${^CAPTURE[1]};

    push @{$self->{tk}->[-1]},
      ${^CAPTURE[0]};

  } else {

    $self->{mlast}=0;
    goto TAIL;

  };

# ---   *   ---   *   ---

  $self->{matches}->[-1]+=
    !$self->{nd}->{opt};

  $self->{nd}->{fn}->($self)
  if $self->has_action();

  $self->{capt}=undef;

TAIL:
  return;

};

# ---   *   ---   *   ---
# pattern alternation

sub OR($self) {

  my $out=1;

  if(!$self->{mlast}) {
    $self->{mint}->[-1]--;
    $self->tkpop();

    push @{$self->{tk}},[];

  } else {

    while($self->{pending}->[0]) {
      shift @{$self->{pending}};

    };

  };

  return $out;

};

# ---   *   ---   *   ---

sub flowop($self) {

  state $tab={
    q[|]=>\&OR,

  };

  my $out=0;
  my $key=$self->{key};

  if(exists $tab->{$key}) {
    $out=$tab->{$key}->($self);

  };

  return $out;

};

# ---   *   ---   *   ---

sub pop_anchor($self) {
  $self->{anchor}=pop @{$self->{an}};
  $self->{anchor}//=$self->{root};

};

# ---   *   ---   *   ---

sub expand_tree($self) {

  if($self->flowop()) {
    ;

  } else {

    push @{$self->{an}},$self->{anchor}
    if @{$self->{nd}->{leaves}}
    && $self->{anchor} ne $self->{root}
    ;

    if(!(

       $self->{key}
    eq $self->{anchor}->{value}

    )) {

      $self->{anchor}=$self->{anchor}->init(
        $self->{key},
        parent=>$self->{anchor}

      );

      my @chain=(@{$self->{nd}->{chain}});
      $self->{anchor}->shift_chain(@chain);

#say $self->{anchor}->{value},q[ ],
#  $self->{anchor}->{fn}
#
#if $self->{anchor}->{fn} ne $NOOP;

    };

    push @{$self->{fn}},[
      $self->{anchor},
      $self->{nd}

    ];

    push @{$self->{matches}},0;
    push @{$self->{mint}},0;

    push @{$self->{tk}},[];

  };

};

# ---   *   ---   *   ---
# walks back modifications to source
# on current branch

sub tkpop($self) {

  my $ar=pop @{$self->{tk}};

  if(defined $ar) {
    my $rt=join q[],@$ar;

    my $sref=$self->{sref};
    $$sref=$rt.$$sref;

  };

};

# ---   *   ---   *   ---
# execute actions for a non-re branch

sub branch_fn($self) {

  my ($branch,$nd) = @{ (pop @{$self->{fn}}) };

  my $matches      = $self->{matches};
  my $mint         = $self->{mint};

  $branch->{mfull} = 0;
  $self->{mlast}   = 0;

  $mint->[-2]++;
  my $mm=0;

  # on match

  if(

     ($matches->[-1] && $mint->[-1])
  && ($matches->[-1] >= $mint->[-1])

  ) {

    $nd->{fn}->($branch)
    if $nd->{fn} ne $NOOP;

    $mm=1;

    $self->{mlast}=1;
    $matches->[-2]++;

    $branch->{mfull}=1;

    # rewind branch on greedy modifier
    if($nd->{greed}) {

      unshift @{$self->{pending}},$nd;

      push    @{$self->{an}},$branch
      if $self->{an}->[-1] ne $branch;

      $nd->{opt}|= 0b10;

    };

  # no match, but branch is optional
  } elsif($nd->opt_branch()) {
    $mint->[-2]--;

    if($nd->{greed}) {

      $nd->{opt}&= ~0b10;

      pop @{$self->{an}}
      if $self->{an}->[-1] eq $branch;

    };

  # no match
  } else {
    $branch->purge();

  };

# ---   *   ---   *   ---

#my ($tree)=$branch->root();
#$tree->prich();
#
#map {say $ARG} @{$self->{tk}->[-1]};
#say q[**],${$self->{sref}};

# ---   *   ---   *   ---

  pop @$matches;
  pop @$mint;

};

# ---   *   ---   *   ---
1; # ret

