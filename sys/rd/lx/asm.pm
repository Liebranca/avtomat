#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX ASM
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

package rd::lx::asm;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::PM;

  use rd::lx::common;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# custom import method to
# make wrappers

sub import($class) {

  # get package we're merging with
  my $dst=rcaller;

  # ^add instruction wrappers
  impwraps $dst,'$self->asm_ins_parse' => q(
    $self,$branch

  ),

  map {["${ARG}_parse" => "\$branch"]}
  qw  (load store);



  return;

};

# ---   *   ---   *   ---
# keyword table

sub cmdset($class,$ice) {


  # get ctx
  my $rd  = $ice->{rd};
  my $mc  = $rd->{mc};

  my $imp = $mc->{ISA}->imp();


  # give instruction list
  return (

    ( map {$ARG => [$OPT_QLIST]}
      @{$imp->list()}

    ),

    'asm-ins'   => [$OPT_QLIST],

  );

};

# ---   *   ---   *   ---
# template: read instruction

sub asm_ins_parse($self,$branch) {

  # get ctx
  my $rd   = $self->{rd};
  my $mc   = $rd->{mc};
  my $ISA  = $mc->{ISA};


  # solve argument tree
  my $idex = 0;
  my @list = $self->asm_recarg($branch,\$idex);


  # ^break down array
  my $type=undef;
  my @args=();

  array_map \@list,sub ($kref,$vref) {

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
  $type //= $ISA->deft();


  # write instruction to current segment
  my $have=$mc->exewrite(
    $mc->{scope}->{mem},
    [$type,$branch->{cmdkey},@args]

  );

  # ^catch encoding fail
  $rd->perr("cannot encode instruction")
  if ! length $have;


  return;

};

# ---   *   ---   *   ---
# ^template: read operand

sub asm_arg($self,$branch,$iref) {


  # get ctx
  my $rd  = $self->{rd};
  my $mc  = $rd->{mc};
  my $l1  = $rd->{l1};

  my $src = $branch->{value};
  my @lv  = @{$branch->{leaves}};


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
