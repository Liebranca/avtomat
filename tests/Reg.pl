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

my $mach = Mach->new();
my $mem  = $mach->segnew(0x20);

my $xs   = $mach->{reg}->{xs};
my $ar   = $mach->{reg}->{ar};

$xs->cpy($mem);

$mach->xs_write(['cpy',$ar,0xFFF]);
$mach->xs_run();

$mach->{reg}->prich(fields=>['ax']);
$mach->{reg}->{-seg}->prich();

# ---   *   ---   *   ---
1; # ret
