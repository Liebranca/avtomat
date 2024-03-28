#!/usr/bin/perl
# ---   *   ---   *   ---
# SWITCH
# Turn me off
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmdlib::switch;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# block sub-divider

cmdsub 'switch' => q(opt_qlist) => q{


  # already sorted?
  return if $branch->{vref};


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};


  # select anchor
  my $body=$branch->{parent};
  if(defined $l1->is_branch($body->{value})) {
    $body=$body->{parent};

  };

  # save command arguments
  my @lv   = @{$branch->{leaves}};
  my @args = $self->argtake($branch,int @lv);

  $branch->{vref} = \@args;


  # sort hierarchically and give
  $self->branch_subdiv(
    $body,qw(on or &off)

  );

  return;

};

# ---   *   ---   *   ---
# ^icef*ck

w_cmdsub 'switch' => q(opt_qlist) => qw(
  on or off

);

# ---   *   ---   *   ---
# (?=on/or) [elem] from [list]
# is how we do iterators!

cmdsub 'from' => q(opt_qlist) => q{

  return if $branch->{vref};

  my @args=$self->argtake($branch);

  $branch->{vref}=\@args;
  $branch->clear();


  return;

};

# ---   *   ---   *   ---
