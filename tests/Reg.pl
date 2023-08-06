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
# the bit

my $mach  = Mach->new();
my $scope = $mach->{scope};

my $mem  = $mach->segnew(0x20);

my $xs   = $mach->{reg}->{xs};

my @ins=$mach->ipret(q[
  cpy ar,$FFF;

]);

$xs->cpy($mem);
$mach->xs_write(@ins);
$mach->xs_run();

$mach->{reg}->prich();
$mach->{reg}->{-seg}->prich();

# ---   *   ---   *   ---
1; # ret
