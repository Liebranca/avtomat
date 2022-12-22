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

  our $VERSION = v0.00.3;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,%O) {

  # defaults
  $O{fn}  //= $NULLSTR;
  $O{dom} //= $class;
  $O{opt} //= 0;

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

  if(!is_coderef($O{fn})) {

    if($O{fn} ne $NULLSTR) {

      $O{fn}=
        eval '\&'.$O{dom}.'::'.$O{fn};

    } else {
      $O{fn}=$NOOP;

    };

  };

  $self->{fn}  = $O{fn};
  $self->{opt} = $O{opt};

  return $self;

};

# ---   *   ---   *   ---
# ^from instance

sub init($self,$value,%O) {

  return $self->{frame}->nit(

    value  => $value,
    parent => $self,

    %O

  );

};

# ---   *   ---   *   ---
# clones a node

sub dup($self) {

  my $out     = undef;

  my @anchor  = ();
  my @pending = ($self);

  while(@pending) {

    my $nd=shift @pending;

    my $cpy=$nd->{frame}->nit(

      value  => $nd->{value},
      action => $nd->{fn},

      parent => (@anchor)
        ? (shift @anchor)
        : $out
        ,

    );

    $cpy->{opt}=$nd->{opt};

    $out//=$cpy;

    unshift @anchor,$cpy;
    unshift @pending,@{$nd->{leaves}};

  };

  return $out;

};

# ---   *   ---   *   ---
# rewind the tree match

sub rew($st) {

  $st->{pending}=[@{
    $st->{nd}->{parent}->{leaves}

  }];

};

# ---   *   ---   *   ---
# saves capture to current container

sub capt($st) {

  $st->{frame}->nit(
    $st->{anchor},$st->{capt}

  );

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

sub discard($tree,$match) {
  $tree->pluck($match);

};

# ---   *   ---   *   ---
# makes helper for match

sub match_st($self) {

  my $frame = Tree->get_frame();
  my $root  = $frame->nit(

    undef,
    $self->{value}

  );

# ---   *   ---   *   ---

  my $st=bless {

    root    => $root,
    anchor  => $root,

    capt    => q[],
    nd      => undef,

    frame   => $frame,
    pending => [@{$self->{leaves}}],

    matches => 0,
    mint    => 0,
    mlast   => 0,

    re      => undef,
    key     => undef,

    kls     => $self->{value},
    fn      => [],

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

  my $st   = $self->match_st();
  my $fail = 0;

  while(@{$st->{pending}}) {

    last if !length $s;

    if(!$st->get_next()) {
      $st->branch_fn();
      next;

    };

    $st->attempt(\$s);

    unshift

      @{$st->{pending}},
      @{$st->{nd}->{leaves}},

      0

    ;

  };

  $fail|=$st->{matches} != $st->{mint};

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

  my $frame = Tree->get_frame();
  my $tree  = $frame->nit(undef,$self->{value});

#:!;> storing a reference to the object that
#:!;> spawned this tree, within the tree
#:!;>
#:!;> frankly, quite terrible, and an outright
#:!;> dependency loop. but it works.

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

        $branch->{fn}->(
          $tree,$match

        ) if $branch->{fn} ne $NOOP;

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

sub attempt($self,$sref) {

  if($self->{re}) {
    $self->attempt_match($sref);

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

sub attempt_match($self,$sref) {

  my $re=$self->{re};

  $self->{mint}+=!$self->{nd}->{opt};

  $self->{capt}=undef;

  if($$sref=~ s[^\s*($re)\s*][]) {

    $self->{mlast}=1;
    $self->{capt}=${^CAPTURE[0]};

  } else {

    $self->{mlast}=0;
    goto TAIL;

  };

  $self->{matches}+=!$self->{nd}->{opt};

  $self->{nd}->{fn}->($self)
  if $self->has_action();

  $self->{capt}=undef;

TAIL:
  return;

};

# ---   *   ---   *   ---

sub flowop($self) {

  my $out=0;

  if($self->{key} eq q[|]) {

    if(!$self->{lmatch}) {
      $self->{mint}--;

    };

    $out=1;

  };

  return $out;

};

# ---   *   ---   *   ---

sub solve_anchor($self) {

  my $out = $self->{root};

  my $a   = $self->{anchor}->{parent};
  my $b   = $self->{nd}->{parent};

  goto TAIL if !defined $a || !defined $b;

  if($a->{value} ne $b->{value}) {
    $out=$self->{anchor};

  } else {
    $out=$a;

  };

TAIL:
  return $out;

};

# ---   *   ---   *   ---

sub expand_tree($self) {


  if($self->flowop()) {
    ;

  } else {

    if(!(

       $self->{key}
    eq $self->{anchor}->{value}

    )) {

      $self->{anchor}=$self->{frame}->nit(
        $self->solve_anchor(),$self->{key}

      );

    };

    push @{$self->{fn}},[
      $self->{anchor},
      $self->{nd}->{fn}

    ] if $self->has_action();

  };

};

# ---   *   ---   *   ---
# execute actions for a non-re branch

sub branch_fn($self) {

  my $ref=pop @{$self->{fn}};
  goto TAIL if !defined $ref;

  if($self->{matches} >= $self->{mint}) {

    my ($branch,$fn)=@$ref;
    $fn->($self->{root},$branch);

  };

TAIL:
  return;

};

# ---   *   ---   *   ---
1; # ret
