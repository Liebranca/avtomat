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

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# block sub-divider

cmdsub 'switch' => q(
  qlist src;

) => sub ($self,$branch) {



  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};


  # select anchor
  my $body=$branch->{parent};
  if($l1->typechk(EXP=>$body->{value})) {
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

w_cmdsub 'switch' => q(qlist src) => qw(
  on or off

);

# ---   *   ---   *   ---
# (?=on/or) [elem] from [list]
# is how we do iterators!

w_cmdsub 'csume-list' => q(qlist src) => 'from';

# ---   *   ---   *   ---
