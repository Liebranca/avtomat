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

  use English qw($MATCH);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Arstd::throw;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.3a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# default behavior; gives match exactly
#
# [0]: mem ptr  ; self
# [1]: word     ; uid
#
# [<]: byte ptr ; captured match

sub proto_undo_f {
  return $_[0]->{asis}->[$_[1]];

};


# ---   *   ---   *   ---
# cstruc
#
# [0]: byte ptr  ; class
# [1]: byte pptr ; (k=>v) options
#
# [<]: mem ptr ; new instance

sub new {
  my ($class,%O)=@_;

  # catch bad param
  throw "$class requires an input regex"
  if ! exists $O{inre};

  # set defaults
  my ($fmat,$re)=(
    q[@REPL%u],
    qr{\@REPL(?<uid>\d+)},

  );

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
#
# [0]: mem ptr  ; self

sub clear {
  @{$_[0]->{asis}}=();
  @{$_[0]->{capt}}=();

  return;

};


# ---   *   ---   *   ---
# puts placeholder in place of re
# pushes matches to tab
#
# [0]: mem ptr  ; self
# [1]: byte ptr ; string
#
# [!]: overwrites input string

sub repl {
  while($_[1]=~ $_[0]->{inre}) {
    my @capt = ($MATCH,{%+});
    my $uid  = int @{$_[0]->{asis}};
    my $tok  = sprintf $_[0]->{fmat},$uid;

    push @{$_[0]->{asis}},$capt[0];
    push @{$_[0]->{capt}},$capt[1];

    $_[1]=~ s[$_[0]->{inre}][$tok];

  };

  return;

};


# ---   *   ---   *   ---
# ^replaces placeholder with value
#
# [0]: mem ptr  ; self
# [1]: byte ptr ; function id to call
# [2]: byte ptr ; string
#
# [!]: overwrites input string

sub proto_undo {
  while($_[2]=~ $_[0]->{outre}) {
    my $ct=$_[0]->{$_[1]}->($_[0],$+{uid});
    $_[2]=~ s[$_[0]->{outre}][$ct];

  };

  return;

};


# ---   *   ---   *   ---
# ^lis
#
# [0]: mem ptr  ; self
# [2]: byte ptr ; string
#
# [!]: overwrites input string

sub repv {$_[0]->proto_undo(repv=>$_[1])};
sub undo {$_[0]->proto_undo(undo=>$_[1])};


# ---   *   ---   *   ---
# immediately runs repl+repv
#
# [0]: mem ptr  ; self
# [2]: byte ptr ; string
#
# [!]: overwrites input string

sub proc {
  $_[0]->repl($_[1]);
  $_[0]->repv($_[1]);

  return;

};


# ---   *   ---   *   ---
1; # ret
