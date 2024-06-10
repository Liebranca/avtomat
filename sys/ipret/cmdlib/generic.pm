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

  use   parent 'ipret::cmd';
  BEGIN {ipret::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# solves dbout values

sub echo($self,$branch) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $eng   = $main->{engine};


  # can solve values?
  my @solved=$eng->argtake(map {
    $ARG->{id}

  } @{$branch->{vref}});

  return $branch if ! @solved;


  # all solved, no need to repeat ;>
  $branch->{vref}=\@solved;

  return;

};

# ---   *   ---   *   ---
# hammer time!

sub stop($self,$branch) {};

# ---   *   ---   *   ---
# get symbol size

sub szof($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $eng  = $main->{engine};
  my $l1   = $main->{l1};


  # ~
  my $have = $branch->{value};
     $have = $l1->xlate($have)->{data};

  my $sym  = $eng->symfet($have);

  return $branch if ! $sym;


  my $x=$sym->{size};

  $branch->{value}=$l1->tag(NUM=>$x);
  $branch->{vref}->{res}=$x;


  return (! $branch->{parent})
    ? $x : () ;

};

# ---   *   ---   *   ---
# add entry points

cmdsub stop => q() => \&stop;
cmdsub echo => q() => \&echo;
cmdsub szof => q() => \&szof;

# ---   *   ---   *   ---
1; # ret
