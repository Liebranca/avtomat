#!/usr/bin/perl
# ---   *   ---   *   ---
# GENERIC
# Refuses to elaborate
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::cmdlib::generic;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# solves dbout values

cmdsub echo => q() => q{


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $eng   = $main->{engine};

  my $mc    = $main->{mc};
  my $ptr_t = $mc->{bk}->{ptr};


  # can solve all refs now?
  my @list = @{$branch->{vref}};
  my @repr =map {

    my @have=$eng->value_solve($ARG->{id});
    $have[-1];

  } @list;

  return $branch if @list > @repr;


  say map {

    ($ptr_t->is_valid($ARG))
      ? $ARG->load
      : $ARG
      ;

  } @repr;

  return;

};

# ---   *   ---   *   ---
# hammer time!

cmdsub stop => q() => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $lx   = $main->{lx};
  my $list = $lx->stages;


  # name of stage says *when* to stop!
  my $stage=$branch->{leaves}->[0];

  if($stage) {
    $stage=$l1->is_sym($stage->{value});

  };

  $stage //= $list->[-1];


  # are we there yet? ;>
  if($stage eq $list->[$main->{stage}]) {
    $main->{tree}->prich();
    $main->perr('STOP');

  # ^nope, wait
  } else {
    $branch->{vref}=$stage;
    $branch->clear();

  };

};

# ---   *   ---   *   ---
1; # ret
