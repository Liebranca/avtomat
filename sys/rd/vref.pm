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

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    name => null,

    data => null,
    type => null,

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


  $self->{name}=$self->{data}
  if ! length $self->{name};

  $self->{data}=$self->{name}
  if ! length $self->{data};


  return $self;

};

# ---   *   ---   *   ---
# get values stored by reference
# optionally filter them by type!

sub read_values($self,$filter=null) {

  my @have=($self->{type} eq 'array')
    ? $self->dataflat($self->{data})
    : $self
    ;

  return map {
    $ARG->{data}

  } (length $filter)
    ? grep {$ARG->{type}=~ $filter} @have
    : @have
    ;

};

# ---   *   ---   *   ---
# flatten input to set/add

sub dataflat($self,@data) {

  my @out = ();
  my @Q   = @data;

  while(@Q) {

    my $e=shift @Q;

    if($e->{type} eq 'array') {
      unshift @Q,@{$e->{data}};

    } else {
      push @out,$e;

    };


  };


  return @out;

};

# ---   *   ---   *   ---
# overwrite existing reference

sub set($self,@data) {


  # validate
  return if ! @data;
  @data=$self->dataflat(@data);


  # multiple sources?
  if(1 < @data) {

    $self->{type}='array'
    if $self->{type} ne 'array';

    $self->{data}=\@data;


  # ^single source!
  } else {
    $self->{data}=$data[0]->{data};
    $self->{type}=$data[0]->{type};

  };


  return;

};

# ---   *   ---   *   ---
# ^pack multiple references

sub add($self,@data) {


  # validate
  return if ! @data;
  @data=$self->dataflat(@data);


  # get ctx
  my $class=ref $self;


  # making new array?
  if($self->{type} ne 'array') {


    # have existing value?
    if(length $self->{data}) {

      my $old=$class->new(%$self);

      $self->{data} = [$old,@data];
      $self->{type} = 'array';


    # make array from blank?
    } elsif(1 < @data) {
      $self->{type} = 'array';
      $self->{data} = \@data;


    # ^no NOT make an array!
    } else {
      $self->{type} = $data[0]->{type};
      $self->{data} = $data[0]->{data};

    };


  # ^push to existing!
  } else {
    push @{$self->{data}},@data;

  };


  return;

};

# ---   *   ---   *   ---
# vref contains a given type
# return value if true!

sub is_valid($class,$filter,$ice) {

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
  my @have=$ice->read_values($re);
  return (int @have)
    ? @have
    : null
    ;

};

# ---   *   ---   *   ---
1; # ret
