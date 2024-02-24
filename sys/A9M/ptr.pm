#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M PTR
# Memory reference
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::ptr;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $DEFAULTS=>{

    type   => $Type::DEFAULT,

    ptr_t  => undef,
    segid  => 0x00,
    addr   => 0x00,

    mcid   => 0,

  };

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {


  # defaults
  $class->defnit(\%O);
  $O{segcls} //= caller;


  # make ice
  my $self=bless \%O,$class;


  return $self;

};

# ---   *   ---   *   ---
# get container for value

sub getseg($self) {

  my $class = $self->{segcls};
  my $idex  = $self->{segid};
  my $frame = $class->get_frame($self->{mcid});

  return $frame->getseg($idex);

};

# ---   *   ---   *   ---
# interprets value as an addr

sub read_ptr($self) {

  # get ctx
  my $seg = $self->getseg();
  my $mc  = $seg->getmc();

  # get saved addr
  my $ptrv = $seg->dload(
    $self->{ptr_t},
    $self->{addr}

  );


  # ^unroll and give
  return $mc->decode_ptr($ptrv);

};

# ---   *   ---   *   ---
# put value

sub store($self,$value,%O) {

  # defaults
  $O{deref} //= 1;


  # write at [value]?
  if($O{deref} && $self->{ptr_t}) {

    my ($seg,$off)=$self->read_ptr();

    $seg->dstore(

      $self->{type},
      $value,

      $off,

    );


  # ^nope, use own addr
  } else {

    my $seg=$self->getseg();

    $seg->dstore(

      $self->{type},
      $value,

      $self->{addr}

    );

  };

};

# ---   *   ---   *   ---
# ^fetch

sub load($self,%O) {

  # defaults
  $O{deref} //= 1;


  # read from [value]?
  if($O{deref} && $self->{ptr_t}) {
    my ($seg,$off)=$self->read_ptr();
    return $seg->dload($self->{type},$off);


  # ^nope, use own addr
  } else {

    my $seg=$self->getseg();

    return $seg->dload(
      $self->{type},$self->{addr}

    );

  };

};

# ---   *   ---   *   ---
1; # ret
