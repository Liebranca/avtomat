#!/usr/bin/perl
# ---   *   ---   *   ---
# ICEBOX
# Keeps your instances cold
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Icebox;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Cask;

  use Arstd::PM;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $SHARED=>[qw(
    icemake icepick ice

  )];

# ---   *   ---   *   ---
# importer injections

St::imping {


  # frame cstruc
  '*vstatic'=>sub ($dst,$O) {

    # add frame vars
    $O->{icebox}=sub {Cask->new()};

    # ^add methods to frame
    my $sig  = q($class,$frame,$x);
    my $args = q($frame,$x);

    map {

      # add to table
      push @{$O->{-autoload}},$ARG;

      # ^pass wrapper
      impwraps $dst,
      St::cpkg . "->$ARG" => $sig,

      [$ARG => $args];


    } @$SHARED;


  },


  # loading
  '*regen' => sub($dst,$ice) {
    St::cpkg->regen($ice);

  },


  # ice dstruc
  '*DESTROY' => sub ($dst,$ice) {
    St::cpkg->del($ice);

  },


};

# ---   *   ---   *   ---
# register new

sub icemake($class,$frame,$ice) {

  my $box  = $frame->{icebox};
  my $idex = $box->give($ice);

  $ice->{iced}  = $idex;
  $ice->{frame} = $frame;


  return $idex;

};

# ---   *   ---   *   ---
# ^undo

sub icepick($class,$frame,$ice) {

  my $box=$frame->{icebox};
  $box->take(idex=>$ice->{iced});

  return;

};

# ---   *   ---   *   ---
# ^get existing

sub ice($class,$frame,$idex) {

  my $box=$frame->{icebox};
  my $ice=$box->view($idex);

  return (defined $ice) ? $ice : null ;

};

# ---   *   ---   *   ---
# instance restore hook

sub regen($class,$self) {

  my $frame=$self->{frame};

  return;

};

# ---   *   ---   *   ---
# instance dstruc hook

sub del($class,$self) {

  my $frame=$self->{frame};

  $frame->icepick($self)
  if $frame && $frame->{icebox};


  return;

};

# ---   *   ---   *   ---
1; # ret
