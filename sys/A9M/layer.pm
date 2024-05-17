#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M:LAYER
# Template for pieces
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::layer;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get host machine

sub getmc($self) {

  my $class = $self->{mccls};
  my $frame = $class->get_frame();

  my $mc    = $frame->ice($self->{mcid});

  return $mc;

};

# ---   *   ---   *   ---
# get allocator

sub get_alloc($self) {

  my $mc    = $self->getmc();
  my $alloc = $mc->{alloc};

  return $alloc;

};

# ---   *   ---   *   ---
# add universal flags to object

sub set_uattrs($self,@keys) {

  my $mc    = $self->getmc();
  my $flags = $mc->{bk}->{flags};

  $flags->defnit($self,@keys);


  return;

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {
  return mc=>$self->getmc();

};

# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {

  my $self=(! is_blessref $O)
    ? bless $O,$class
    : $O
    ;

  $self->{mc}=$O->{mc};
  return $self;

};

# ---   *   ---   *   ---
# ^find machine instance

sub REBORN($self) {

  my $mc=$self->{mc};

  $self->{mcid}  = $mc->{iced};
  $self->{mccls} = ref $mc;

  delete $self->{mc};

};

# ---   *   ---   *   ---
1; # ret
