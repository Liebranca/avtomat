#!/usr/bin/perl
# ---   *   ---   *   ---
# SOURCE FILTER
# MACROOOOOOOOOOOOOOOSS!!!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package SourceFilter;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use Filter::Util::Call;

  use lib $ENV{'ARPATH'}.'/lib/sys';

  use Style;
  use Arstd::Array;
  use Arstd::IO;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# GBL

  my $Chain  = [];
  my $Active = {};


# ---   *   ---   *   ---
# cstruc

sub new($class,$fname,$beg) {

  my $self=bless {
    fname   => $fname,
    chain   => $Chain,
    idex    => int @{$Chain},

    data    => [],
    raw     => null,

    lineno  => $beg,

    beg     => qr{(?<!\#) use \s+ $class}x,
    end     => qr{(?<!\#) no  \s+ $class}x,

  },$class;


  $Active->{$class}=$self;
  $self->pluck_use_line() if $Chain->[0];

  push @$Chain,$self;
  return $self;

};


# ---   *   ---   *   ---
# remove self

sub del($self) {
  $self->pluck_use_line();
  $self->code_emit();
  array_lshift $Chain,$self->{idex};
  delete       $Active->{ref $self};

  return;

};


# ---   *   ---   *   ---
# removes 'use' from file

sub pluck_use_line($self) {
  my $line =  $Chain->[0]->{data}->[-1];
  my $raw  = \$Chain->[0]->{raw};

  my ($beg,$end)=(
    $self->{beg},
    $self->{end},

  );

  $$raw=~ s[$beg][]sg;
  $$raw=~ s[$end][]sg;


  return;

};


# ---   *   ---   *   ---
# adds line to own buff

sub logline($self,$stringref) {
  my $out=int($self eq $Chain->[-1]);
  if($out) {
    my $main = $Chain->[0];
    my $i    = $self->{lineno}++;

    $main->{data}->[$i]  = $$stringref;
    $main->{raw}        .= $$stringref;
    $out=1;

  };


  $self->del() if $$stringref=~ $self->{end};
  return $out;

};


# ---   *   ---   *   ---
# executes children nodes

sub propagate($self) {
  map {
    $ARG->code_emit();
    $ARG->del();

  } @{$Chain}[1..@$Chain-1];

  return;

};


# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {
  my $out=ioprocin \%O;
  push @$out,$self->{raw};

  return ioprocout \%O;

};


# ---   *   ---   *   ---
1; # ret
