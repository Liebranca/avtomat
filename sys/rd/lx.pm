#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX
# Slow runner ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::lx;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Re;
  use Arstd::PM;
  use Arstd::IO;

  use rd::lx::common;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  TABID   => 'CMD',
  DEFAULT => {

    main  => undef,

    links => [],
    queue => [],

  },

  deps  => [qw(

    rd::lx::cmd
    rd::lx::dd

    rd::lx::asm

  )],

  subex=>qr{^(?:
    throw_ | Frame_Vars$ | cmdset$

  )}x,

  stages=>[qw(parse solve xlate run)],

};

# ---   *   ---   *   ---
# custom import method to
# load implementations

sub import($class) {


  my $deps=$class->deps();
  map {cloadi $ARG} @$deps;


  submerge $deps,

  main  => $class,
  subex => $class->subex();


  return;

};

# ---   *   ---   *   ---
# reset per-expression state

sub exprbeg($self,$rec=0) {

  # get ctx
  my $Q     = $self->{queue};
  my $have  = $self->{links};

  my $ahead = [];


  # preserve current?
  if($rec > 0) {
    push @$Q,$have;

  # ^restore previous?
  } else {
    $ahead   = pop @$Q;
    $ahead //= [];

  };


  # set or clear state
  @$have=@$ahead;

};

# ---   *   ---   *   ---
# records sub-expression result

sub exprlink($self,$have) {

  my $main  = $self->{main};
  my $links = $self->{links};

  if(defined $have) {
    push @$links,$have;
    return $have;

  } else {
    return;

  };

};

# ---   *   ---   *   ---
# name of subroutine for current
# rd/ipret step

sub stagef($self,$key) {

  my $CMD   = $self->load_CMD();

  my $stage = $self->stagename();
  my $fn    = $CMD->{$key}->{$stage};


  return $fn;

};

# ---   *   ---   *   ---
# get name of current rd/ipret step

sub stagename($self) {

  return $self->stages()->[
    $self->{main}->{stage}

  ];

};

# ---   *   ---   *   ---
# keyword table

sub cmdset($self) {

  return {

    # dbout
    echo => [$QLIST],
    stop => [],

    # import external
    map {$ARG->cmdset($self)}
    @{$self->deps()}

  };

};

# ---   *   ---   *   ---
# selfex

sub stop_parse($self,$branch) {

  my $main=$self->{main};

  $main->{tree}->prich();
  $main->perr('STOP');

};

# ---   *   ---   *   ---
# template: collapse cmdlist in
# reverse hierarchical order

sub rcollapse_cmdlist($self,$branch,$fn) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};


  # first token, first command
  my @list = $l1->is_cmd($branch->{value});
  my $par  = $branch->{parent};

  # ^get tokens from previous iterations
  push @list,@{$branch->{vref}}
  if exists $branch->{vref};

  $branch->{vref} = \@list;


  # parent is command, keep collapsing
  my $head = $l1->is_cmd($par->{value});
  if(defined $head) {

    # save commands to parent, they'll be
    # picked up in the next run of this F
    $par->{vref} //= [];
    push @{$par->{vref}},@list;

    # ^remove this token
    $branch->flatten_branch();


    return;


  # ^stop at last node in the chain
  } else {
    $fn->();

  };

};

# ---   *   ---   *   ---
# generate/fetch command table

sub load_CMD($self,$update=0) {


  # skip update?
  my $tab=$self->classcache($self->TABID);

  return $tab
  if int %$tab &&! $update;


  # ^nope, regen!
  my $cmdset = $self->cmdset();
  my @keys   = keys %$cmdset;

  %$tab=(


    # re to match any command name
    -re=>re_eiths(

      \@keys,

      opscape => 1,
      bwrap   => 1,
      whole   => 1,

    ),


    # command list [cmd=>attrs]
    map {


      # get name of command
      my $key   = $ARG;
      my $args  = $cmdset->{$key};

      my $plkey =  $key;
         $plkey =~ s[\-][_]sxmg;


      # get subroutine variants of
      # command per rd/ipret step
      $key => {

        -args=>$args,

        map { $ARG => codefind(
          (ref $self),"${plkey}_$ARG"

        )} @{$self->stages()}

      };


    } @keys

  );


  return $tab;

};

# ---   *   ---   *   ---
1; # ret
