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

package rd::cmdlib::generic;

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
# consume node list

cmdsub 'csume-list' => q(qlist) => q{

  return if $branch->{vref};

  my @args=$self->argtake($branch);

  $branch->{vref}=\@args;
  $branch->clear();


  return;

};

# ---   *   ---   *   ---
# ^icef*ck

w_cmdsub 'csume-list' => q(qlist) => 'echo';

# ---   *   ---   *   ---
# hammer time!

cmdsub stop => q(opt_sym) => q{


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