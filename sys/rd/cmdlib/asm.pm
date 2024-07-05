#!/usr/bin/perl
# ---   *   ---   *   ---
# ASM
# Pseudo assembler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmdlib::asm;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

  use rd::vref;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.2;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# custom import method to
# make wrappers

sub build($class,$main) {

  # get ctx
  my $mc     = $main->{mc};
  my $guts_t = $mc->{ISA}->guts_t;

  # make wrappers for whole instruction set
  wm_cmdsub $main,'asm-ins' => q(
    qlist args;

  ) => @{$guts_t->list};

  # give table
  return rd::cmd::MAKE::build($class,$main);

};

# ---   *   ---   *   ---
# offset within current segment

sub current_byte($self,$branch) {

  $branch->{vref}=rd::vref->new(
    type => 'SYM',
    spec => '$',
    data => $branch,

  );

  return;

};

# ---   *   ---   *   ---
# template: read instruction

sub parse_ins($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};


  # expand argument list
  my @args = map {

    if($l1->typechk(LIST=>$ARG->{value})) {
      @{$ARG->{leaves}};

    } else {
      $ARG;

    };

  } @{$branch->{leaves}};


  # ^get type of each argument
  @args=map {

    $ARG = $ARG->discard();

    my $key  = $ARG->{value};
    my $have = $l1->xlate($key);
    my $type = $have->{type};
    my $spec = $have->{spec};


    # memory operand?
    if($type eq 'SCP' && $spec eq '[') {
      $type='MEM';


    # operand size specifier?
    } elsif($type eq 'TYPE') {

      $branch->{vref} //= rd::vref->new_list();
      $branch->{vref}->add($have);

      $type=null;

    };


    # give descriptor
    (length $type)
      ? rd::vref->new(data=>$ARG,type=>$type)
      : ()
      ;


  } @args;


  # have opera type spec?
  my $opsz_def = defined $branch->{vref};
  my @vtypes   = rd::vref->is_valid(
    TYPE=>$branch->{vref}

  );

  my $opsz     = ($opsz_def)
    ? typefet @vtypes
    : $ISA->def_t
    ;


  # get instruction name
  my $name=$branch->{cmdkey};


  # give descriptor
  return {

    name     => $name,

    opsz     => $opsz,
    opsz_def => ! $opsz_def,

    args     => \@args,

  };

};

# ---   *   ---   *   ---
# mutate into generic command ;>

sub mutate_ins($self,$branch,$head,$new='asm-ins') {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};


  # record name of original
  # just for dbout!
  my $full=(! $head->{opsz_def})
    ? "$head->{name} $head->{opsz}->{name}"
    : "$head->{name}"
    ;

  # ^mutate, clear and give
  $branch->{value}=
    $l1->tag(CMD=>$new)
  . $full
  ;

  $branch->clear();
  $branch->{vref}->{res}=$head;

  return;

};

# ---   *   ---   *   ---
# generic instruction

sub asm_ins($self,$branch) {


  # get ctx
  my $main    = $self->{frame}->{main};
  my $ISA     = $main->{mc}->{ISA};

  my $meta_re = $ISA->{guts}->meta_re;


  # save operands to branch
  my $head=$self->parse_ins($branch);
  my $name=($head->{name}=~ $meta_re)
    ? 'meta-ins'
    : 'asm-ins'
    ;


  # mutate and give
  $self->mutate_ins($branch,$head,$name);

  return;

};

# ---   *   ---   *   ---
# add entry points

cmdsub 'asm-ins'  => q(qlist src) => \&asm_ins;
cmdsub '$' => q() => \&current_byte;

# ---   *   ---   *   ---
# generic methods, see ipret
# for details

w_cmdsub 'csume-token' => q(
  sym any;

) => qw(
  blk entry proc

);

w_cmdsub 'csume-list' => q(
  cmd input;

) => 'in';

w_cmdsub 'asm-ins' => q(
  qlist src;

) => qw(reus pass);

# ---   *   ---   *   ---
1; # ret
