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

  our $VERSION = v0.01.1;#b
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
    data => $branch,
    type => 'nsym',

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
    my $have = undef;
    my $type = undef;


    # register operand
    if($l1->typechk(REG=>$key)) {
      $type='r';

    # memory operand
    } elsif($l1->typechk(SCP=>$key)) {
      $type='m';


    # operation tree?
    } elsif($have) {
      $type='opr';

    # symbol fetch?
    } elsif($l1->typechk(SYM=>$key)) {
      $type='sym';


    # operand size specifier?
    } elsif($l1->typechk(TYPE=>$key)) {

      my $have=$l1->untag($key);
         $type=null;

      $branch->{vref} //=
        rd::vref->new(array=>[]);

      $branch->{vref}->add(rd::vref->new(
        data => $have->{spec},
        type => 'type',

      ));


    # ^immediate!
    } else {
      $type='i';

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
    type=>$branch->{vref}

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
  $branch->{vref}->{data}=$head;
  $branch->{vref}->{type}='asm-ins';

  return;

};

# ---   *   ---   *   ---
# generic instruction

sub asm_ins($self,$branch) {

  # save operands to branch
  my $head=$self->parse_ins($branch);

  # mutate and give
  $self->mutate_ins($branch,$head,'asm-ins');

  return;

};

# ---   *   ---   *   ---
# add entry points

cmdsub 'asm-ins' => q(qlist src) => \&asm_ins;
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

# ---   *   ---   *   ---
1; # ret
