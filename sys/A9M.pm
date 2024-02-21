#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M
# The Arcane 9 Machine
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Arstd::PM;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# GBL

sub icebox($class) {
  state  $ar=[];
  return $ar;

};

sub ice($class,$idex) {
  return $class->icebox()->[$idex];

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{memroot} //= 'non';


  # get machine id
  my $icebox = $class->icebox();
  my $id     = @$icebox;

  # find components through methods
  my $bk={
    vmem => $class->get_vmem_bk(),

  };


  # make ice
  my $self=bless {

    cas => $bk->{vmem}->mkroot(
      mcid  => $id,
      label => $O{memroot},

    ),

  },$class;

  # ^add to box
  push @$icebox,$self;


  return $self;

};

# ---   *   ---   *   ---
# find components

sub get_component($class,$name) {

  my $pkg="A9M\::$name";

  cload  $pkg;
  return $pkg;

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$class->get_component] => q[$class],

  map {["get_${ARG}_bk" => "'$ARG'"]}
  qw  (vmem)

);

# ---   *   ---   *   ---
1; # ret
