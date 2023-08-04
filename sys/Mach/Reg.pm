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

  our $VERSION = v0.00.2;#b
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

      wed   fast;


    <seg-ptr>
      reg32 loc;
      reg32 addr;

      wed   fast;

      cpy   &ptr_cpy;
      deref &ptr_deref;

  ]);

# ---   *   ---   *   ---
# copy addr of seg to ptr

sub ptr_cpy($self,$other) {

  my ($loc,$addr)=array_keys($other->{addr});

  $self->{loc}->set(num=>$loc);
  $self->{addr}->set(num=>$addr);

};

# ---   *   ---   *   ---
# ^get seg from stored addr

sub ptr_deref($self) {

  my ($loc,$addr)=$self->to_bytes(32);

  my $class = ref $self->{-seg};
  my $out   = $class->fetch($loc,$addr);

  return $out;

};

# ---   *   ---   *   ---
1; # ret
