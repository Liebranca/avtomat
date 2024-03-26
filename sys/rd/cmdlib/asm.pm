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

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::Bytes;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# custom import method to
# make wrappers

sub build($class,$main) {

  # get ctx
  my $mc     = $main->{mc};
  my $guts_t = $mc->{ISA}->guts_t;

  # make wrappers for whole instruction set
  my @fuck=wm_cmdsub $main,'asm-ins' => q(
    opt_qlist

  ) => @{$guts_t->list()};


  # give table
  return rd::cmd::build($class,$main);

};

# ---   *   ---   *   ---
# template: read instruction

cmdsub 'asm-ins' => q(opt_qlist) => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};


  # solve argument tree
  my $idex = 0;
  my @list = $self->asm_recarg($branch,\$idex);


  # ^break down array
  my $type=undef;
  my @args=();

  Arstd::Array::nmap \@list,sub ($kref,$vref) {

    my $k=$$kref;
    my $v=$$vref;

    if($k ne 'type') {
      push @args,$v;

    } else {
      $type=$v;

    };


  },'kv';


  # ^catch unsolvable args
  return null
  if grep {! length $ARG} @args;

  # fetch default instruction size
  $type //= $ISA->def_t;


  # write instruction to current segment
  my $have=$mc->exewrite(
    $mc->{scope}->{mem},
    [$type,$branch->{cmdkey},@args]

  );

  # ^catch encoding fail
  $main->perr("cannot encode instruction")
  if ! length $have;


  return;

};

# ---   *   ---   *   ---
# ^template: read operand

sub asm_arg($self,$branch,$iref) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};

  my $src  = $branch->{value};
  my @lv   = @{$branch->{leaves}};


  # recurse on list
  if(defined $l1->is_list($src)) {
    return $self->asm_recarg($branch,$iref);


  # ^have plain number?
  } elsif(defined (my $num=$l1->is_num($src))) {

    my $type=(16 > bitsize $num)
      ? 'ix'
      : 'iy'
      ;

    return

       "arg".$$iref++
    => {type=>$type,imm=>$num};


  # ^have type specifier?
  } elsif(defined (my $type=$l1->is_type($src))) {

    return

      type=>$branch->{vref},
      $self->asm_recarg($branch,$iref);


  # ^plain value or value tree
  } else {

    my $y=$self->value_solve($branch);
    my $x=$l1->quantize($y);


    # solve failed?
    if(! length $x) {


      # edge case: src is register
      my $reg  = $mc->{bk}->{anima};
      my $idex = $reg->tokin($src);

      if(defined $idex) {

        return

           "arg".$$iref++
        => {type=>'r',reg=>$idex};


      # ^src is unknown/invalid
      } else {
        return "arg".$$iref++ => null;

      };

    };


    # solve succesfull, identify value type
    my $ptrcls = $mc->{bk}->{ptr};

    # do the ptr dance!
    if($ptrcls->is_valid($x)) {

      return "arg".$$iref++ => {

        type => 'mimm',

        seg  => $mc->segid($x->getseg()),
        imm  => $x->{addr},

      };

    };


    return "arg".$$iref++ => null;

  };

};

# ---   *   ---   *   ---
# ^recursively

sub asm_recarg($self,$branch,$iref) {
  map {$self->asm_arg($ARG,$iref)}
  @{$branch->{leaves}};

};

# ---   *   ---   *   ---
1; # ret
