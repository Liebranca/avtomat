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

Readonly my $PROGRAMS=>[

  # set executable segment
  q'cl  $00;'
. q'cpy xs,[insblk];',

  # ^write to it
  q'cpy ar,$FFF;',

];

# ---   *   ---   *   ---
# the bit

my $mach  = Mach->new();
my $scope = $mach->{scope};

my $mem  = $mach->segnew('insblk',0x20);

my $xs   = $mach->{reg}->{xs};
my $ar   = $mach->{reg}->{ar};

map {

  my @ins=$mach->ipret($ARG);

  $mach->xs_write(@ins);
  $mach->xs_run();

} @$PROGRAMS;

$mem->prich();
$mach->{reg}->{-seg}->prich();

$ar->prich();

# ---   *   ---   *   ---
1; # ret
