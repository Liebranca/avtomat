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
  use Mach::Struc;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
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

    <seg-ptr>
      reg64 loc;
      reg64 addr;

      cpy   &ptr_cpy;
      deref &ptr_deref;

  ]);

# ---   *   ---   *   ---
# copy addr of seg to ptr

sub ptr_cpy($self,$other) {

  my ($loc,$addr)=$other->iof();

  $self->{loc}->set(num=>$loc);
  $self->{addr}->set(num=>$addr);

};

# ---   *   ---   *   ---
# ^get seg from stored addr

sub ptr_deref($self) {

  my ($loc,$addr)=$self->to_bytes(64);

  my $class = ref $self->{-seg};
  my $frame = $class->get_frame($loc);
  my $out   = $frame->{-icebox}->[$addr];

  return $out;

};

# ---   *   ---   *   ---
1; # ret
