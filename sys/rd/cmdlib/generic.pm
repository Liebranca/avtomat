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

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# consume single token

sub csume_token($self,$branch) {


  my @args=$self->argtake($branch);

  $branch->{vref}=$args[0];
  $branch->clear();


  return;

};

# ---   *   ---   *   ---
# ^consume N tokens ;>

sub csume_tokens($self,$branch) {


  my @args=$self->argtake($branch);

  $branch->{vref}=$args[0];
  $branch->clear();


  return;

};

# ---   *   ---   *   ---
# consume node list

sub csume_list($self,$branch) {


  my @args=$self->argtake($branch);

  $branch->{vref}=\@args;
  $branch->clear();


  return;

};

# ---   *   ---   *   ---
# hammer time!

sub stop($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $lx   = $main->{lx};
  my $list = $lx->stages;

  my $vref = $branch->{vref};


  # name of stage says *when* to stop!
  my $stage=$vref->{at};

  if(Tree->is_valid($stage)) {
    $stage=$l1->untag($stage->{value});
    $stage=$stage->{spec};

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

  return;

};

# ---   *   ---   *   ---
# get size of

sub szof($self,$branch) {


  # get ctx
  my $main=$self->{frame}->{main};

  # get argument
  my ($have)=@{$branch->{leaves}};
  $have //= $branch->next_leaf();

  # ^validate
  $main->perr(
    'no argument for [ctl]:%s',
    args => ['sizeof'],

  ) if ! $have;


  # cleanup and give
  $branch->{value} .= $have->discard()->{value};
  $branch->clear();

  return;

};

# ---   *   ---   *   ---
# add entry points

cmdsub 'csume-token' => q(
  nlist src;

) => \&csume_token;

cmdsub 'csume-tokens' => q(
  nlist src;

) => \&csume_tokens;

cmdsub 'csume-list' => q(
  qlist src;

)  => \&csume_list;

w_cmdsub 'csume-list' => q(qlist src) => 'echo';

cmdsub stop => q(
  sym at=reparse;

) => \&stop;

cmdsub 'szof' => q(
  sym src;

)  => \&szof;

# ---   *   ---   *   ---
1; # ret
