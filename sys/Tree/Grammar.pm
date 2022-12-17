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

  our $VERSION = v0.00.2;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,%O) {

  # defaults
  $O{action}   //= $NOOP;
  $O{optional} //= 0;

  my $self=Tree::nit(

    $class,
    $frame,

    $O{parent},
    $O{value},

    %O

  );

  $self->{action}   = $O{action};
  $self->{optional} = $O{optional};

  return $self;

};

# ---   *   ---   *   ---
# clones a node

sub dup($self) {

  my $cpy=$self->{frame}->nit(

    value  => $self->{value},
    action => $self->{action},

    parent => undef,

  );

  return $cpy;

};

# ---   *   ---   *   ---
# rewind the tree match

sub rew($st) {

  unshift

    @{$st->{pending}},
    $st->{nd}->{parent}

  ;

};

# ---   *   ---   *   ---
# saves capture to current container

sub push_to_anchor($st) {

  $st->{frame}->nit(
    $st->{anchor},$st->{capt}

  );

};

# ---   *   ---   *   ---
# terminates an expression

sub term($st) {

  $st->{anchor}     = $st->{nd}->walkup();
  @{$st->{pending}} = ();

# @{$st->{anchor}->{leaves}}

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

    re      => undef,
    key     => undef,

    kls     => $self->{value},

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

    $st->get_next();
    $st->attempt(\$s);

    # early exit if no match on
    # non-optional token
    if($st->{matches} < $st->{mint}) {
      last;

    };

    unshift

      @{$st->{pending}},
      @{$st->{nd}->{leaves}}

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

sub parse($self,$s) {

  my $frame = Tree->get_frame();
  my $tree  = $frame->nit(undef,$self->{value});

  while(1) {

    my $matched=0;

    # test each branch against string
    for my $branch(@{$self->{leaves}}) {

      my ($match,$ds)=$branch->match($s);

      # update string and append
      # to tree on succesful match
      if($match ne $NULL) {

        $tree->pushlv($match);

        $s=$ds;
        $matched|=1;

        last if !length $s;

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

  $self->{key} =
  $self->{re}  = $self->{nd}->{value}
  ;

  $self->{re}  = undef if !is_qre($self->{re});
  $self->{key} = undef if defined $self->{re};

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

sub attempt_match($self,$sref) {

  my $re=$self->{re};

  $self->{mint}+=!$self->{nd}->{optional};

  $self->{capt}=undef;

  if($$sref=~ s[^\s*($re)\s*][]) {
    $self->{capt}=${^CAPTURE[0]}

  } else {
    goto TAIL;

  };

  $self->{matches}+=1;

  my $has_action=

     defined $self->{nd}->{action}
  && $self->{nd}->{action} ne $NOOP
  ;

  $self->{nd}->{action}->($self)
  if $has_action;

  $self->{capt}=undef;

TAIL:
  return;

};

# ---   *   ---   *   ---

sub expand_tree($self) {

  $self->{anchor}=$self->{frame}->nit(
    $self->{root},$self->{key}

  ) unless(

     $self->{key}
  eq $self->{anchor}->{value}

  );

};

# ---   *   ---   *   ---
1; # ret
