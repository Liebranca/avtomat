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

  our $VERSION = v0.00.5;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# pastedef

sub _inline($self,$branch) {

  # get ctx
  my $main = $self->{frame}->{main};
  my $eng  = $main->{engine};
  my $l1   = $main->{l1};


  # ~
  my $name = $branch->{vref}->{data};
     $name = $l1->xlate($name)->{spec};

  my $sym  = $eng->symfet($name);

  return $branch if ! $sym;


  # validate linked sub-tree
  my $stree = $sym->{p3ptr};
  my $have  = $l1->typechk(CMD=>$stree->{value});

  if(! $have || $have->{spec} ne 'proc') {

    $main->perr(
      "non-proc symbol '%s' passed to inline",
      args=>[$name],

    );

  };


  # all OK, get proc contents
  my $tree = $stree->{parent};

  my $stop = $l1->tag(CMD=>'asm-ins') . 'ret';
     $stop = qr"\Q$stop";

  # ^duplicate block
  my @have = map {
    $ARG->dupa(undef,'vref');

  } $tree->match_until($stree,$stop);


  # ^replace branch with block!
  $branch->pushlv(@have);
  $main->{l2}->recurse($branch);

  $branch->flatten_branch();


  return;

};

# ---   *   ---   *   ---
# solves dbout values

sub echo($self,$branch) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $eng   = $main->{engine};
  my $vref  = $branch->{vref};


  # can solve values?
  my @solved=$eng->argtake(
    $vref->read_values()

  );

  return $branch if ! @solved;


  # all solved, no need to repeat ;>
  $branch->{vref}->{data}=\@solved;

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

cmdsub inline => q() => \&_inline;

cmdsub stop   => q() => \&stop;
cmdsub echo   => q() => \&echo;
cmdsub szof   => q() => \&szof;

# ---   *   ---   *   ---
1; # ret
