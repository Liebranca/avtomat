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
  use Arstd::PM;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  list => [qw(

    rd::cmdlib::generic

    rd::cmdlib::macro
    rd::cmdlib::switch

    rd::cmdlib::dd
    rd::cmdlib::asm

  )],

  next_link => 'ipret::cmdlib',

  extend_l1 => 1,
  type_list => [qw(EXE CMD REG)],

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


  map {
    my $fn="use_$ARG";
    $class->$fn($main);

  } @{$class->type_list};


  return;


};

# ---   *   ---   *   ---
# add binary token type

sub use_EXE($class,$main) {


  # get ctx
  my $l1  = $main->{l1};
  my $mc  = $main->{mc};
  my $mem = $mc->{bk}->{mem};

  # register type and pattern
  $l1->extend(EXE=>'$'=>sub {

    my $src   = $_[0];

    my $valid =
       $mem->is_valid($src)
    && $src->{executable};

    $src=$src->{iced} if $valid;


    return ($valid,$src,$NULLSTR);

  });

  return;

};

# ---   *   ---   *   ---
# add function token type

sub use_CMD($class,$main) {


  # get ctx
  my $l1=$main->{l1};
  my $lx=$main->{lx};

  # register type and pattern
  $l1->extend(CMD=>'*'=>sub {

    # get ctx
    my $tab = $lx->load_CMD();
    my $src = lc $_[0];

    # match symbol name against table
    my $valid=$src=~ $tab->{-re};

    return ($valid,$src,$NULLSTR);

  });

  return;

};

# ---   *   ---   *   ---
# add vmc register token type

sub use_REG($class,$main) {


  # get ctx
  my $l1    = $main->{l1};
  my $mc    = $main->{mc};
  my $anima = $mc->{anima};

  # register type and pattern
  $l1->extend(REG=>'='=>sub {

    my $src   = lc $_[0];
       $src   = $anima->tokin($src);

    my $valid = defined $src;


    return ($valid,$src,$NULLSTR);

  });

  return;

};

# ---   *   ---   *   ---
1; # ret
