#!/usr/bin/perl
# ---   *   ---   *   ---
# MINT
# Makes coins ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mint;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;#a
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  # expr for fetching reference type
  ref_t => qr{^

    [^=]* (?: \=?
      (HASH|ARRAY|CODE)

    )

  }x,

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$src) {

  return bless {

    walked => {},
    Q      => [$src],

  },$class;

};

# ---   *   ---   *   ---
# consume value from Q

sub get_next($self) {


  # get ctx
  my $Q      = $self->{Q};
  my $walked = $self->{walked};

  return undef if ! int @$Q;


  # skip repeated
  rept: my $vref = shift @$Q;

  goto rept if ! defined $vref
            ||   exists  $walked->{$vref};


  # ^add first to table and give
  $walked->{$vref}=1;

  return $vref;

};

# ---   *   ---   *   ---
# ^inspect value
#
# if it contains other values,
# expand it and pass them through an F
#
# returns the processed values!

sub vex($self,$fn,$args) {


  # find or stop
  my $vref=$self->get_next();
  return () if ! defined $vref;

  $args //= [];


  # get reference type
  my $walked = $self->{walked};

  my @have   = ();
  my $refn   = ref $vref;

  my ($type) = $vref =~ $self->ref_t;

  return () if ! defined $type;


  # have hash?
  if($type eq 'HASH') {

    @have=map  {
      $vref->{$ARG}=$fn->($vref->{$ARG},@$args);
      $vref->{$ARG};

    } grep {
        defined $vref->{$ARG}
    &&! exists  $walked->{$vref->{$ARG}}

    } keys %$vref;


  # have array?
  } elsif($type eq 'ARRAY') {

    @have=

    map {
      $vref->[$ARG]=$fn->($vref->[$ARG],@$args);
      $vref->[$ARG];

    } grep {
        defined $vref->[$ARG]
    &&! exists  $walked->{$vref->[$ARG]}

    } 0..@$vref-1;

  };


  return grep {defined $ARG} @have;

};

# ---   *   ---   *   ---
# apply F to nested structure

sub proc($class,$obj,$fn,@args) {


  # make ice
  my $self = $class->new($obj);
  my $Q    = $self->{Q};

  while(@$Q) {
    push @$Q,$self->vex($fn,\@args);

  };

  return;

};

# ---   *   ---   *   ---
1; # ret
