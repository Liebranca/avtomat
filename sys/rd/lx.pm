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

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.0;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  deps=>[qw(

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
# cstruc

sub new($class,$rd) {

  return bless {

    rd    => $rd,

    links => [],
    queue => [],

  },$class;

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

  my $links=$self->{links};

  if(defined $have) {
    push @$links,$have;
    return $have;

  } else {
    return ();

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
    $self->{rd}->{stage}

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

  my $rd=$self->{rd};

  $rd->{tree}->prich();
  $rd->perr('STOP');

};

# ---   *   ---   *   ---
# template: collapse cmdlist in
# reverse hierarchical order

sub rcollapse_cmdlist($self,$branch,$fn) {


  # get ctx
  my $rd = $self->{rd};
  my $l1 = $rd->{l1};
  my $l2 = $rd->{l2};


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
  $self->{_cmd_cache} //= {};

  my $CMD=$self->{_cmd_cache};
  return $CMD if int %$CMD &&! $update;


  # regen cache
  my $cmdset = $self->cmdset();
  my @keys   = keys %$cmdset;


  $CMD={


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

  };


  $self->{_cmd_cache}=$CMD;
  return $CMD;

};

# ---   *   ---   *   ---
1; # ret
