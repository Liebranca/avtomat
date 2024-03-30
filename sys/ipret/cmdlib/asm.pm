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

package ipret::cmdlib::asm;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Arstd::Bytes;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# solve instruction arguments

cmdsub 'asm-ins' => q() => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};
  my $enc  = $main->{encoder};

  # unpack
  my $vref = $branch->{vref};
  my $name = $vref->{name};
  my $opsz = $vref->{opsz};


  # solve args
  my @args=map {

    my $nd   = $ARG->{value};
    my $key  = $nd->{value};
    my $type = $ARG->{type};

    my %O    = ();


    # have register?
    if($type eq 'r') {
      %O=(reg=>$l1->quantize($key));


    # have immediate?
    } elsif($type eq 'i') {

      my $ximm=$ISA->enc_t->ix_bs;

      $type=($ximm >= bitsize $O{imm})
        ? "${type}x"
        : "${type}y"
        ;

      %O=(imm=>$l1->quantize($key));

    };


    # give descriptor
    $O{type}=$type;
    \%O;


  } @{$vref->{args}};


  # write opcode to tmp
  my ($have,$size)=$enc->encode(
    [[$opsz,$name,@args]]

  );

  # ^catch encoding fail
  $main->perr(
    "cannot encode instruction",
    lvl=>$AR_FATAL

  ) if ! length $have;


  # write to current segment!
  my $scope = $mc->{scope};
  my $mem   = $scope->{mem};

  $mem->strwrite($have,$size);

  return;

};

# ---   *   ---   *   ---
1; # ret
