#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH REG(-ister)
# Globals are inevitable
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

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
  use Mach::Struc;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  strucs(q[

    <reg8>
      byte a;


    <reg16>
      byte low;
      byte high;


    <reg32>
      reg16 low;
      reg16 high;


    <reg64>
      reg32 low;
      reg32 high;

      # attrs
      wed   fast;

      # methods
      ptr_cpy   &ptr_cpy;
      ptr_deref &ptr_deref;

  ]);

# ---   *   ---   *   ---
# copy addr of seg to ptr

sub ptr_cpy($self,$other) {
  $self->set(ptr=>$other);

};

# ---   *   ---   *   ---
# ^get seg from stored addr

sub ptr_deref($self) {

  my ($loc,$addr)=$self->to_bytes(32);

  my $frame = $self->{-seg}->{frame};
  my $mach  = $frame->{-mach};

  my $out   = $mach->fetch_seg($loc,$addr);

  return $out;

};

# ---   *   ---   *   ---
1; # ret
