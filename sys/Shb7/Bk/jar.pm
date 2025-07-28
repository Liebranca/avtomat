#!/usr/bin/perl
# ---   *   ---   *   ---
# BK JAR
# wrappers for java/kotlin
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::jar;
  use v5.42.0;
  use strict;
  use warnings;

  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::Path;
  use Arstd::IO;
  use Arstd::PM;

  use Arstd::WLog;

  use parent 'Shb7::Bk';
  use lib "$ENV{ARPATH'}/lib/";


# ---   *   ---   *   ---
# selective inheritance

  submerge(
    ['Shb7::Bk::flat'],
    subok => qr{(?:fupdated|fdeps)},

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# add entry to build files

sub push_src($self,$fpath) {
  push @{$self->{file}},Shb7::Bfile->new(

    $fpath,
    $self,

    obj_ext=>q[.jar],
    dep_ext=>q[.jard],
    asm_ext=>undef,

  );

  return $self->{file}->[-1];

};


# ---   *   ---   *   ---
# object file boiler

sub fbuild($self,$bfile,$bld) {
  $WLog->substep(Shb7::shpath($bfile->{src}));

  # invoke compiler
  ($bld->{lang} eq 'kotlin')
    ? $self->kotlinc($bfile)
    : $self->javac($bfile)
    ;


  # ^give on success
  if(-f $bfile->{obj}) {
    return 1;

  # else crash
  } else {
    errout("jar: build fail",lvl=>$AR_FATAL);

  };

};


# ---   *   ---   *   ---
# building java

sub javac($self,$bfile) {
  my @call=(
    'javac' => $bfile->{src},
    -d      => $bfile->{obj},

  );

  system {$call[0]} @call;
  return;

};


# ---   *   ---   *   ---
# building kotlin

sub kotlinc($self,$bfile) {
  my @call=(
    'kotlinc' => $bfile->{src},
    -d        => $bfile->{obj},

  );

  system {$call[0]} @call;
  return;

};


# ---   *   ---   *   ---
1; # ret
