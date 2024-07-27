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

  our $VERSION = v0.00.4;#a
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
# put value at addr
# if no addr, use stack pointer

sub store($self,$type,$value,$off=0x00) {


  # get ctx
  my $base = $self->{base}->load();
  my $ptr  = $self->{ptr}->load();

  $type = typefet $type;


  # need to update stack base?
  if(! $base) {
    $base=$ptr;
    $self->{base}->store($base);

  };


  # find addr
  my $push =! $off;
  my $addr =  ($push)
    ? $ptr-$type->{sizeof}
    : $base-$off
    ;

  # save value and adjust ptr if need
  $self->{mem}->store($type=>$value,$addr);
  $self->{ptr}->store($addr) if $push;


  return $addr;

};

# ---   *   ---   *   ---
# ^read!

sub load($self,$type,$value,$off=0x00) {


  # get ctx
  my $base = $self->{base}->load();
  my $ptr  = $self->{ptr}->load();

  $type = typefet $type;


  # are we popping?
  my $pop  =! $off;
  my $addr =  ($pop)
    ? $ptr-$type->{sizeof}
    : $base-$off
    ;


  # get value and adjust ptr if need
  my $out=$self->{mem}->load(
    $type=>$value,$addr

  );

  $self->{ptr}->store(
    $addr+$type->{sizeof}

  ) if $pop;


  return $out;

};

# ---   *   ---   *   ---
# redirect pointer to stack reference

sub repoint($self,$dst,$off=0x00) {

  my $type=(defined $dst->{ptr_t})
    ? $dst->{ptr_t} : $dst->{type} ;

  my $addr=(! $off)
    ? $self->store($type,0x00)
    : $self->{base}->load()-$off
    ;

  $dst->{segid} = $self->{mem}->{iced};
  $dst->{addr}  = $addr;


  return $type->{sizeof};

};

# ---   *   ---   *   ---
# checks if ptr is referencing stack

sub is_ptr($self,$dst) {
  return $dst->{segid} eq $self->{mem}->{iced};

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
