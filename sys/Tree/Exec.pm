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
# lyeb,

# ---   *   ---   *   ---
# deps

package Tree::Exec;

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

  our $VERSION = v0.00.2;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# leaf cstruc

sub nit(

  # implicit
  $class,
  $frame,

  # actual
  $parent,
  $call,
  $nd

) {

  # get ice
  my $self=Tree::nit(

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
  my $self  = $frame->nit(undef,'ROOT',undef);

  return $self;

};

# ---   *   ---   *   ---
# executes functions

sub walk($self,$ctx) {

  $self->{rip} = $self->{leaves}->[0];
  $self->{jmp} = undef;

  return if ! defined $self->{rip};

  my @pending  = $self->{rip};

  while(@pending) {

    my $f   = shift @pending;
    my $nd  = $f->{nd};
    my $rip = $self->{rip};

    $f->{value}->($ctx,$f->{nd})
    unless $nd->{plucked};

    # ptr was overwritten
    if($self->{jmp}) {

      $rip=$self->{rip}=($self->{jmp} ne $NULL)
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

};



# ---   *   ---   *   ---
# go to specific node

sub jmp($self,$to) {

  while(

       defined $to
  && ! defined $to->{xbranch}

  ) {

    $to=$to->next_leaf();

  };

  $self->{jmp}=(defined $to)
    ? $to->{xbranch}
    : $NULL
    ;

};

# ---   *   ---   *   ---
1; # ret
