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


      # determine operand types...
      map {

        if(defined (my $idex=$l1->is_reg($ARG))) {

          $stk |= $idex == 0xB;
          push @reg,$idex;

        } else {
          push @imm,$l1->quantize($ARG);

        };


      # ^from branch values
      } map {
        $ARG->{value}

      } map {

        my @lv=@{$ARG->{leaves}};
           @lv=$ARG if ! @lv;

        @lv;

      } @{$beg->{leaves}};


      # [sb-i]
      if($stk) {
        %O=(imm=>$imm[0]);
        $type.='stk';


      # [r+i]
      } elsif(@reg == 1 && @imm <= 1) {

        $imm[0] //= 0;

        %O=(

          seg=>$ptrseg,

          reg=>$reg[0],
          imm=>$imm[0],

        );

        $type.='sum';


      # [seg:r+r+i*x]
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


      # [seg:i]
      } else {

        $imm[0] //= 0;

        %O=(

          seg=>$ptrseg,
          imm=>$imm[0],

        );

        $type.='imm';

      };


    # symbol deref
    } elsif($type eq 'sym') {

      my $have=$l1->quantize($nd->{value});
      return $branch if ! length $have;

      %O=(
        seg  => $mc->segid($have->getseg),
        imm  => $have->{addr},

      );

      $type='mimm';
      $opsz=($branch->{vref}->{opsz_def})
        ? $have->{type}
        : $opsz
        ;

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


  # map int to bytes ;>
  ($opcd,$size)=
    $enc->format_opcd([$opcd,$size]);

  # ^write to current segment!
  my $mem = $mc->{segtop};
  $mem->strwrite($opcd,$size);

  return;

};

# ---   *   ---   *   ---
# sets current scope

cmdsub 'self' => q() => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};

  # can find symbol?
  my $name = $l1->is_sym($branch->{vref});
  my $sym  = $mc->ssearch($name);

  return $branch if ! length $sym;


  # set scope
  $mc->scope($sym->{value});

  return;

};

# ---   *   ---   *   ---
1; # ret
