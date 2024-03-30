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
  use Type;
  use Bpack;

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


    # have memory?
    } elsif($type eq 'm') {


      my $beg=$nd->{leaves}->[0];
         $beg=$beg->{leaves}->[0];

      my @reg = ();
      my @imm = ();
      my $stk = 0;

# ---   *   ---   *   ---
# TODO: segment tables!

my $seg    = $mc->ssearch('non','data');
my $ptrseg = $mc->segid($seg);

# ---   *   ---   *   ---


      map {

        if(defined (my $idex=$l1->is_reg($ARG))) {

          $stk |= $idex == 0xB;
          push @reg,$idex;

        } else {
          push @imm,$l1->quantize($ARG);

        };

      } map {
        $ARG->{value}

      } map {

        my @lv=@{$ARG->{leaves}};
           @lv=$ARG if ! @lv;

        @lv;

      } @{$beg->{leaves}};


      if($stk) {
        %O=(imm=>$imm[0]);
        $type.='stk';

      } elsif(@reg == 1 && @imm <= 1) {

        $imm[0] //= 0;

        %O=(

          seg=>$ptrseg,

          reg=>$reg[0],
          imm=>$imm[0],

        );

        $type.='sum';

      } elsif(@reg == 2 || @imm == 2) {

        $reg[0] //= 0;
        $reg[1] //= 0;

        $imm[0] //= 0;
        $imm[1] //= 0;

        %O=(

          seg   => $ptrseg,

          rX    => $reg[0],
          rY    => $reg[1],

          imm   => $imm[0],
          scale => $imm[1],

        );

        $type.='lea';

      } else {

        $imm[0] //= 0;

        %O=(

          seg=>$ptrseg,
          imm=>$imm[0],

        );

        $type.='imm';

      };

    };


    # give descriptor
    $O{type}=$type;
    \%O;


  } @{$vref->{args}};


  # write opcode to tmp
  my ($opcd,$size)=$enc->encode_opcd(
    $opsz,$name,@args

  );

  # ^catch encoding fail
  $main->perr(
    "cannot encode instruction",
    lvl=>$AR_FATAL

  ) if ! length $opcd;


  # ~
  ($opcd,$size)=
    $enc->format_opcd([$opcd,$size]);


  # write to current segment!
  my $scope = $mc->{scope};
  my $mem   = $scope->{mem};

  $mem->strwrite($opcd,$size);

  return;

};

# ---   *   ---   *   ---
1; # ret
