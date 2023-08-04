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

  use Mach::Struc;
  use Mach::Reg;

# ---   *   ---   *   ---
# decl

struc(q[

  <Anima>
    seg-ptr xs;
    reg64   pad;

]);

# ---   *   ---   *   ---
# the bit

my $anima = Mach::Struc->ice('Anima');
my $mem   = Mach::Seg->new(0x10);

my $xs    = $anima->{xs};

$xs->cpy($mem);
$anima->prich();

# ---   *   ---   *   ---
1; # ret
