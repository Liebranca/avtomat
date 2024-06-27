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

  our $VERSION = v0.00.4;#a
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
# repeat N times!

sub rept($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # unpack args
  my ($n,$body)=@{$branch->{leaves}};
  $n=$l1->xlate($n->{value})->{spec};

  my @body=@{$body->{leaves}};
  my @have=map {

    map {

      if($l1->typechk(EXP=>$ARG->{value})) {
        map {$ARG->dupa(undef,'vref','-uid')}
        @{$ARG->{leaves}};

      } else {
        $ARG->dupa(undef,'vref','-uid');

      };

    } @body;

  } 0..$n-1;


  my $par  = $branch->{parent};
  my $idex = $have[0]->{-uid};

  $branch->clear();
  $par->uid_shift($branch,int @have);

  map {
    $have[$ARG]->{-uid}=$idex+$ARG;

  } 0..$#have;

  $branch->pushlv(@have);
  $branch->flatten_branch();

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

w_cmdsub 'csume-token' => q(
  sym name;

) => qw(inline);

w_cmdsub 'csume-list' => q(qlist src) => 'echo';

cmdsub 'rept' => q(
  num   N;
  curly body;

)  => \&rept;

cmdsub stop => q(
  sym at=reparse;

) => \&stop;

cmdsub 'szof' => q(
  sym src;

)  => \&szof;

# ---   *   ---   *   ---
1; # ret
