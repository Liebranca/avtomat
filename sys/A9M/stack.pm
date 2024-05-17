#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M STACK
# A pile of plates!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::stack;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Type;
  use Warnme;

  use parent 'A9M::sysmem';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  ROOTID => 'STACK',
  cnt    => 0x20,

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {


  # defaults
  $O{mcid}  //= 0;
  $O{mccls} //= caller;


  # make ice
  my $self=bless {

    %O,

    mem  => undef,

    base => undef,
    ptr  => undef,

  },$class;


  # make container
  $self->mkroot();


  # get handle to registers
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};

  $self->{base} = $anima->fetch($anima->stack_base);
  $self->{ptr}  = $anima->fetch($anima->stack_ptr);


  # find ptrs and give
  $self->regen;
  return $self;

};

# ---   *   ---   *   ---
# forcefully clear stack and
# set it's pointers back to top

sub reset($self) {

  $self->{base}->store(0x00);
  $self->{ptr}->store($self->total);
  $self->{mem}->clear();

  return;

};

# ---   *   ---   *   ---
# regen ptrs

sub regen($self) {


  # get handle to registers
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};

  $self->{base} = $anima->fetch($anima->stack_base);
  $self->{ptr}  = $anima->fetch($anima->stack_ptr);


  # ^zero flood and give
  $self->reset;
  return;

};

# ---   *   ---   *   ---
# cleanup kick

sub REBORN($self) {

  A9M::sysmem::REBORN($self);
  $self->regen;

  return;

};

# ---   *   ---   *   ---
1; # ret
