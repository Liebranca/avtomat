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
  use Mach;

# ---   *   ---   *   ---
# ROM

# TODO:
#
# * char/str imm to num

Readonly my $PROGRAMS=>[

  # setup executable segment
  q[

    # clear root block
    clr   $00;

    # get mem for next program
    cpy   ar,$696E73;
    alloc xs,ar,$20;

  ],

  # ^write instructions to
  # the allocated block
  q[

    cpy ar,$FFF;

  ],

];

# ---   *   ---   *   ---
# the bit

my $mach  = Mach->new();
my $scope = $mach->{scope};

my $xs   = $mach->{reg}->{xs};
my $ar   = $mach->{reg}->{ar};

map {

  my @ins=$mach->ipret($ARG);

  $mach->xs_write(@ins);
  $mach->xs_run();

} @$PROGRAMS;

$mach->{reg}->{-seg}->prich();

my $mem=$scope->get(qw(SYS ins))->deref();
$mem->prich();

# ---   *   ---   *   ---
1; # ret
