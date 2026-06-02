#!/usr/bin/perl
# ---   *   ---   *   ---

# ---   *   ---   *   ---
# deps

package Mach::Reg;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Array;

  use Mach;

# ---   *   ---   *   ---
# ROM

# TODO:
#
# * char/str imm to num

Readonly my $PROGRAM=>[

  # setup executable segment
  boot=>q[

    # clear root block
    clr   $00;

    # get mem for next block
    cpy   ar,'crux';
    alloc xs,ar,$20;

  ],

  # ^write instructions to
  # the allocated block
  crux=>q[

    push $FF2;
    pop  ar;

  ],

];

# ---   *   ---   *   ---
# the bit

my $mach  = Mach->new();
my $scope = $mach->{scope};

my $xs    = $mach->{reg}->{xs};
my $ar    = $mach->{reg}->{ar};

my $tab   = {@$PROGRAM};

map {

  my @ins=$mach->ipret($tab->{$ARG});

  $mach->xs_write($ARG,@ins);
  $mach->xs_run() if $ARG eq 'boot';

} array_keys($PROGRAM);

$mach->{reg}->{-seg}->prich();

my $mem=$scope->get(qw(SYS ins))->deref();
$mem->prich();

# ---   *   ---   *   ---
1; # ret
