#!/usr/bin/perl
# ---   *   ---   *   ---
# Cask
# It's all take and give
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Cask;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Arstd::Bytes qw(bitscanf);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v1.00.8';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub mask_sz     {1 << 6};
sub mask_cap    {(1 << mask_sz())-1};
sub slot_mask   {mask_sz()-1};


# ---   *   ---   *   ---
# cstruc

sub new($class,@data) {
  # calc how many qword masks we need
  my $cnt = int @data;
  my $rem = $cnt % mask_sz();
  my $cap = $cnt + (mask_sz() - $rem);

  # ^spawn [mask,data] slot array
     $rem  = $cnt;
  my $top  = 0;
  my $qcnt = int($cap/mask_sz());
  my $self = [];

  for(0..$qcnt-1) {
    my $chunk=get_chunk($rem);
    my @chunk=@data[$top..$chunk-1];
    new_slot($self,$rem,@chunk);

    # go next and give
    $top+=$chunk;
    $rem-=$chunk;
  };

  return bless $self,$class;
};


# ---   *   ---   *   ---
# up to mask size elements per mask

sub get_chunk {
  return ($_[0] > mask_sz())
    ? mask_sz()
    : $_[0]
    ;
};


# ---   *   ---   *   ---
# makes new slot

sub new_slot($self,$rem,@data) {
  # ensure data is as big as mask_sz
  my $have=int @data;
  if($have < mask_sz()) {
    push @data,map {null} 0..mask_sz()-$have-1;
  };

  # ^each slot holds the occupation mask
  # ^plus the data
  my $out={
    mask => (1 << get_chunk($rem))-1,
    data => [@data],
  };

  push @$self,$out;
  return $out;
};


# ---   *   ---   *   ---
# get number of slots

sub used($self) {
  return int(@$self);
};


# ---   *   ---   *   ---
# get next avail slot

sub avail($self) {
  # get idex of last slot
  my $top=$self->used();

  # give new on empty?
  return {
    slot=>$self->new_slot(0),
    idex=>[0,0],

  } if ! $top;

  # go backwards (newest first) until
  # we find a slot with available space
  my $slot;
  do    {$slot=$self->[--$top]}
  while ($top > 0 && $slot->{mask} == mask_cap());

  # no viable slot found?
  # then make new
  if(! defined $slot
  || $slot->{mask} == mask_cap()) {
    my $eid=$self->used();
    return {
      slot=>$self->new_slot(0),
      idex=>[0,$eid],
    };
  };

  # get first unset bit in mask
  my $bit=bitscanf(~ $slot->{mask})-1;

  # ^give slot plus coordinates
  return {
    slot=>$slot,
    idex=>[$bit,$top],
  };
};


# ---   *   ---   *   ---
# reuse free element or make new
#
# [<]: qword uid

sub take($self,$value) {
  my $avail = $self->avail();
  my $slot  = $avail->{slot};
  my $bit   = $avail->{idex}->[0];
  my $eid   = $avail->{idex}->[1];

  $slot->{mask} |= 1 << $bit;
  $slot->{data}->[$bit]=$value;

  my $uid=($eid*mask_sz())+$bit;
  return $uid;
};


# ---   *   ---   *   ---
# ^mark element at idex as free

sub give($self,$uid) {
  my ($bit,$eid)=rduid($uid);
  my $slot=$self->[$eid];

  # clear bit from mask
  $slot->{mask} &=~ (1 << $bit);

  # reset element is not actually needed,
  # but we do it anyway
  $slot->{data}->[$bit]=null;

  return;
};


# ---   *   ---   *   ---
# get [eid,bit] from uid

sub rduid {
  # lower 6 bits of uid are slot idex
  # upper 10 bits are mask bit
  my $bit=$_[0] & slot_mask();
  my $eid=int($_[0]/slot_mask());

  return ($bit,$eid);
};


# ---   *   ---   *   ---
# get slot from uid

sub slotat($self,$uid) {
  my ($bit,$eid)=rduid($uid);
  return ($eid < $self->used())
    ? $self->[$eid]
    : undef
    ;
};


# ---   *   ---   *   ---
# get value from uid

sub view($self,$uid) {
  my ($bit,$eid)=rduid($uid);
  return ($eid < $self->used())
    ? $self->[$eid]->{data}->[$bit]
    : undef
    ;
};


# ---   *   ---   *   ---
# trash it all!

sub clear($self) {
  @$self=();
  return;
};


# ---   *   ---   *   ---
1; # ret
