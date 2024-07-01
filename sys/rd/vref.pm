#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:VREF
# Token to hashref
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::vref;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Chk;
  use Type;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    type => null,
    spec => null,
    data => null,

    defv => undef,
    res  => undef,

  },

  retab => {},

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  $class->defnit(\%O);
  my $self=bless {%O},$class;

  return $self;

};

# ---   *   ---   *   ---
# ^make vref list

sub new_list($class,$data=undef) {

  $data=[] if ! defined $data;

  return $class->new(
    type => 'LIST',
    spec => 'vref',
    data => $data,

  );

};

# ---   *   ---   *   ---
# get values stored by reference
# optionally filter them by type!

sub read_values($self,$attr,$filter=null) {

  my @have=($self->{type} eq 'LIST')
    ? $self->flatten($attr=>$self)
    : $self
    ;

  return map {
    $ARG->{$attr}

  } (length $filter)
    ? grep {$ARG->{type}=~ $filter} @have
    : @have
    ;

};

# ---   *   ---   *   ---
# flatten instance array

sub flatten($class,@ice) {


  # get actual class if called from ice
  if(length ref $class) {
    @ice=($class) if ! @ice;
    $class=ref $class;

  };


  # walk instance list
  my @out = ();
  my @Q   = @ice;

  while(@Q) {

    my $e=shift @Q;


    # recurse on array
    if($e->{type} eq 'LIST') {
      unshift @Q,@{$e->{data}};

    # else add to out
    } else {

      $e=$class->new(%$e)
      if ! St::is_valid($class,$e);

      push @out,$e;

    };


  };


  return @out;

};

# ---   *   ---   *   ---
# copy values from another instance

sub copy($self,$other) {

  my $tab=$self->DEFAULT;

  map {
    $self->{$ARG}=$other->{$ARG};

  } keys %$tab;


  return;

};

# ---   *   ---   *   ---
# overwrite existing reference

sub set($self,@other) {


  # validate
  return if ! @other;
  @other=$self->flatten(@other);


  # multiple sources?
  if(1 < @other) {

    $self->{type}='LIST'
    if $self->{type} ne 'LIST';

    $self->{spec}='vref';
    $self->{data}=\@other;


  # ^single source!
  } else {
    $self->copy($other[0]);

  };


  return;

};

# ---   *   ---   *   ---
# ^pack multiple references

sub add($self,@other) {


  # validate
  return if ! @other;
  @other=$self->flatten(@other);


  # get ctx
  my $class=ref $self;


  # making new array?
  if($self->{type} ne 'LIST') {


    # have existing value?
    if(length $self->{data}) {

      my $old=$class->new(%$self);

      $self->{type} = 'LIST';
      $self->{spec} = 'vref';
      $self->{data} = [$old,@other];


    # make array from blank?
    } elsif(1 < @other) {
      $self->{type} = 'LIST';
      $self->{spec} = 'vref';
      $self->{data} = \@other;


    # ^do NOT make an array!
    } else {
      $self->copy($other[0]);

    };


  # ^push to existing!
  } else {
    push @{$self->{data}},@other;

  };


  return;

};

# ---   *   ---   *   ---
# vref contains a given type
# return value if true!

sub is_valid($class,$filter,$ice,$attr='spec') {

  # invalid input?
  return null
  if ! $class->is_valid($ice);


  # get re for this filter?
  my $re=$filter;
  if(! is_qre $re) {

    $class->retab->{$filter}=qr{^$filter$}
    if ! exists $class->retab->{$filter};

    $re=$class->retab->{$filter}

  };


  # unpack reference and give
  my @have=$ice->read_values($attr,$re);
  return (int @have)
    ? @have
    : null
    ;

};

# ---   *   ---   *   ---
1; # ret
