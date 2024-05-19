#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:CMDLIB
# Where the defs at?
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmdlib;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Arstd::Array;
  use Arstd::PM;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  list => [qw(

    rd::cmdlib::generic

    rd::cmdlib::macro

    rd::cmdlib::dd
    rd::cmdlib::asm

  )],

  next_link => 'ipret::cmdlib',

  extend_l1 => 1,
  type_list => [qw(EXE $ CMD * REG =)],

};

# ---   *   ---   *   ---
# fetch definitions from
# sub-packages

sub load($class,$main) {

  $class->load_types($main);

  map {

    # fetch pkg
    cloadi $ARG;
    my $tab=$ARG->build($main);

    # extract cstruc args
    {values %$tab};


  } @{$class->list};

};

# ---   *   ---   *   ---
# adds token types to L1
#
# ignored if the "extend_l1"
# class attr is unset!

sub load_types($class,$main) {

  my $list = $class->type_list;

  my @nk   = array_keys   $list;
  my @nv   = array_values $list;

  map {

    my $key   = $nk[$ARG];
    my $value = $nv[$ARG];

    my $fn    = "use_$key";
       $fn    = \&$fn;

    $main->{l1}->extend($key=>$value=>$fn);

  } 0..$#nk;


  return;


};

# ---   *   ---   *   ---
# detect binary token type

sub use_EXE($main,$src) {


  # get ctx
  my $l1    = $main->{l1};
  my $mc    = $main->{mc};
  my $mem   = $mc->{bk}->{mem};

  # run checks
  my $valid =
     $mem->is_valid($src)
  && $src->{executable};

  $src=$src->{iced} if $valid;


  return ($valid,$src,$NULLSTR);

};

# ---   *   ---   *   ---
# detect function token type

sub use_CMD($main,$src) {

  # get ctx
  my $lx  = $main->{lx};

  my $tab = $lx->load_CMD();
     $src = lc $src;

  # match symbol name against table
  my $valid=$src=~ $tab->{-re};

  return ($valid,$src,$NULLSTR);

};

# ---   *   ---   *   ---
# add vmc register token type

sub use_REG($main,$src) {

  # get ctx
  my $l1    = $main->{l1};
  my $mc    = $main->{mc};
  my $anima = $mc->{anima};

  # find valid
  $src = lc $src;
  $src = $anima->tokin($src);

  my $valid = defined $src;

  return ($valid,$src,$NULLSTR);

};

# ---   *   ---   *   ---
1; # ret
