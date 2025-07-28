#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD REPL
# Poor man's tokenizer
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::Repl;
  use v5.42.0;
  use strict;
  use warnings;

  use Carp;
  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;
  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

St::vconst {
  FMAT => q[@REPL%u],
  RE   => qr{\@REPL(?<uid>\d+)},

};


# ---   *   ---   *   ---
# default behaviors

sub proto_undo_f($self,$uid) {
  return $self->{asis}->[$uid];

};


# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # catch bad param
  croak "$class requires an input regex"
  if ! exists $O{inre};

  # set defaults
  my ($fmat,$re)=($class->FMAT,$class->RE);

  $O{pre}   //= 'STR';
  $O{repv}  //= \&proto_undo_f;
  $O{undo}  //= \&proto_undo_f;


  # make ice and give
  my $self=bless {
    outre => qr{$O{pre}$re},
    fmat  => "$O{pre}$fmat",
    asis  => [],
    capt  => [],

    %O,

  },$class;


  return $self;

};


# ---   *   ---   *   ---
# clears state

sub clear($self) {
  @{$self->{asis}}=();
  @{$self->{capt}}=();

  return;

};


# ---   *   ---   *   ---
# puts placeholder in place of re
# pushes matches to tab

sub repl($self,$sref) {
  while($$sref=~ $self->{inre}) {
    my @capt = ($MATCH,{%+});
    my $uid  = int @{$self->{asis}};
    my $tok  = sprintf $self->{fmat},$uid;

    push @{$self->{asis}},$capt[0];
    push @{$self->{capt}},$capt[1];

    $$sref=~ s[$self->{inre}][$tok];

  };

  return;

};


# ---   *   ---   *   ---
# ^replaces placeholder with value

sub proto_undo($self,$fn,$sref) {
  while($$sref=~ $self->{outre}) {
    my $ct=$self->{$fn}->($self,$+{uid});
    $$sref=~ s[$self->{outre}][$ct];

  };

  return;

};


# ---   *   ---   *   ---
# ^lis

sub repv {$_[0]->proto_undo(repv=>$_[1])};
sub undo {$_[0]->proto_undo(undo=>$_[1])};


# ---   *   ---   *   ---
# immediately runs repl+repv

sub proc {
  $_[0]->repl($_[1]);
  $_[0]->repv($_[1]);

  return;

};


# ---   *   ---   *   ---
1; # ret
