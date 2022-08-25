#!/usr/bin/perl
# ---   *   ---   *   ---
# ST
# Fundamental structures
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package St;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use Scalar::Util qw(blessed reftype);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Frame;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {{}};

# ---   *   ---   *   ---
# global state

  my $Frames={};

# ---   *   ---   *   ---
# is obj instance of class

sub is_valid($kind,$obj) {
  return blessed($obj) && $obj->isa($kind);

};

# what clas obj is an instance of
sub get_class($obj) {return ref $obj};

# ---   *   ---   *   ---
# create instance container

sub new_frame($class,%O) {

  $O{-owner_kls}//=(caller)[0];

  my $vars=$class->Frame_Vars();
  map {$O{$ARG}//=$vars->{$ARG}} keys %$vars;

  $O{-class}=$class;

  my $frame=Frame::new(%O);
  $Frames->{$class}//=[];

  push @{$Frames->{$class}},$frame;

  return $frame;

};

# ---   *   ---   *   ---
# ^get existing

sub get_frame($class,$i=0) {

  my $out;

  if(!exists $Frames->{$class}) {

    $out=$class->new_frame(
      -owner_kls=>(caller)[0]

    );

  } else {
    $out=$Frames->{$class}->[$i];

  };

  return $out;

};

# ---   *   ---   *   ---
1; # ret
