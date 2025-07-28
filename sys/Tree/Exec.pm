#!/usr/bin/perl
# ---   *   ---   *   ---
# EXEC
# A tree of calls
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Tree::Exec;
  use v5.42.0;
  use strict;
  use warnings;

  use English;

  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Chk;

  use Arstd::IO;

  use parent 'Tree';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# leaf cstruc

sub new(

  # implicit
  $class,
  $frame,

  # actual
  $parent,
  $call,
  $nd

) {

  # get ice
  my $self=Tree::new(

    $class,
    $frame,

    $parent,
    $call

  );

  $self->{nd}=$nd;

  return $self;

};

# ---   *   ---   *   ---
# ^tree cstruc

sub new_root($class) {

  my $frame = $class->new_frame();
  my $self  = $frame->new(undef,'ROOT',undef);

  $self->{prev} = [];

  return $self;

};

# ---   *   ---   *   ---
# ^from Tree::Grammar array

sub new_cstack($self,$keepx,@branches) {

  # get next method for each branch
  my @calls=map {

    $ARG->shift_branch(
      keepx => $keepx,
      frame => $self->{frame}

    )

  } @branches;

  # ^filter out undef
  @calls=grep {defined $ARG} @calls;

  # ^clear tree and set new callstack
  $self->clear();
  $self->pushlv(@calls);

};

# ---   *   ---   *   ---
# ^store current

sub push_cstack($self) {

  my $hist   = $self->{prev};
  my @cstack = $self->walk_cstack();

  @cstack=map {
    my $par=$ARG->{parent};
    $par->pluck($ARG);

  } @cstack;

  push @$hist,[@cstack];

};

# ---   *   ---   *   ---
# ^load

sub pop_cstack($self) {

  my $hist   = $self->{prev};
  my @cstack = @{(pop @$hist)};

  $self->clear();
  $self->pushlv(@cstack);

};

# ---   *   ---   *   ---
# goes through remaining
# nodes without execution

sub walk_cstack($self) {

  my @out=();
  my $rip=$self->{rip};

  return () if ! defined $rip;


  # go through child nodes
  my @pending=$rip;

  while(@pending) {

    my $f=shift @pending;
    push @out,$f;

    $rip=$rip->next_leaf();
    last if ! defined $rip;

    push @pending,$rip;

  };

  return @out;

};

# ---   *   ---   *   ---
# ^executes

sub walk($self,$ctx) {

  my $out=null;

  $self->{rip} = $self->{leaves}->[0];
  $self->{jmp} = undef;

  return if ! defined $self->{rip};


  # go through child nodes
  my @pending=$self->{rip};

  while(@pending) {

    my $f   = shift @pending;
    my $nd  = $f->{nd};
    my $rip = $self->{rip};

    $out=$f->{value}->($ctx,$f->{nd})
    unless $nd->{plucked};

    # ptr was overwritten
    if($self->{jmp}) {

      $rip=$self->{rip}=($self->{jmp} ne null)
        ? $self->{jmp}
        : undef
        ;

      $self->{jmp}=undef;

    # ^no jmp, go to next
    } else {
      $rip=$self->{rip}->next_leaf();

    };

    last if ! defined $rip;

    $self->{rip}=$rip;
    push @pending,$rip;

  };


  return $out;

};

# ---   *   ---   *   ---
# go to specific node

sub jmp($self,$to) {

  while(

      defined $to
  &&! defined $to->{xbranch}

  ) {

    $to=$to->next_leaf();

  };

  $self->{jmp}=(defined $to)
    ? $to->{xbranch}
    : null
    ;

};

# ---   *   ---   *   ---
1; # ret
