#!/usr/bin/perl
# ---   *   ---   *   ---
# LYFIL
# The master of filters
# not a filter itself
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package lyfil;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use style;
  use arstd;

# ---   *   ---   *   ---
# info

  our $VERSION=0.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# global state

  our $M=[];

# ---   *   ---   *   ---

sub nit($fname,$beg) {

  my $class=(caller)[0];
  my $self=bless {

    fname=>$fname,
    chain=>$M,
    idex=>int(@{$M}),

    data=>[],
    raw=>NULLSTR,

    lineno=>$beg,

    end=>qr{(?<!#)no $class},

  },$class;

  push @$M,$self;
  return $self;

};

# ---   *   ---   *   ---

sub del($self) {

  $self->{run}->();
  arstd::arrshf($M,$self->{idex})

};

# ---   *   ---   *   ---

sub logline($self,$string) {

  if($self eq $self->{chain}->[-1]) {

    $self->{chain}->[0]
    ->{data}->[$self->{lineno}++]

    =

    $string

    ;

    $self->{chain}->[0]->{raw}.=$string;

  };

  if($string=~ $self->{end}) {$self->del()};

};

# ---   *   ---   *   ---

sub propagate($self) {

  my @ar=@{$M};
  for my $f(@ar[1..$#ar]) {
    $f->code_emit();

  };

};

# ---   *   ---   *   ---

sub prich($self,%opt) {

  # opt defaults
  $opt{errout}//=0;

  # select filehandle
  my $FH=($opt{errout}) ? *STDERR : *STDOUT;

# ---   *   ---   *   ---

  return print {$FH} $self->{raw};

};

# ---   *   ---   *   ---
1; # ret
