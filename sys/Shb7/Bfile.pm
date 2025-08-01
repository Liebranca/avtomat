#!/usr/bin/perl
# ---   *   ---   *   ---
# BFILE
# Intermediate stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Bfile;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

  use Arstd::Path qw(dirof reqdir);
  use Arstd::IO qw(errout);

  use Shb7;

  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

St::vconst {
  AVTOPATH=>"$ENV{ARPATH}/avtomat/",
  LDOK_RE=>qr{
    Shb7\:\:Bk\:\:(?: gcc|flat)

  }x,

};


# ---   *   ---   *   ---
# cstruc

sub new($class,$fpath,$bk,%O) {
  $O{out}//=null;

  my $self=bless {
    src => $fpath,
    out => $O{out},
    bk  => $bk,

    obj => Shb7::obj_from_src(
      $fpath,
      ext=>$O{obj_ext}

    ),

    dep => Shb7::obj_from_src(
      $fpath,
      ext=>$O{dep_ext}

    ),

    asm => Shb7::obj_from_src(
      $fpath,
      ext=>$O{asm_ext}

    ),

  },$class;


  # make paths and give
  reqdir dirof $self->{obj};
  return $self;

};


# ---   *   ---   *   ---
# build output is valid ld input

sub linkable($self) {
  my $class=ref $self->{bk};
  return int($class=~ $self->LDOK_RE);

};


# ---   *   ---   *   ---
# give 1 if object was rebuilt

sub update($self,$bld) {
  return (
     $self->{bk}->fupdated($self)
  || $bld->{clean}

  ) ? $self->{bk}->fbuild($self,$bld)
    : 0
    ;

};


# ---   *   ---   *   ---
# check object date against dependencies

sub buildchk($self,$do_build,$deps,%O) {

  # early exit?
  $O{clean}//=0;
  return 1 if $O{clean} || $$do_build;

  # ^go on, check!
  map {

    # found dep is updated?
    if(-f $ARG && Shb7::ot($self->{obj},$ARG)) {
      $$do_build=1;
      return;

    };

  } @$deps;


  return;

};


# ---   *   ---   *   ---
# sanity check: dependency files exist

sub depchk($self,$deps) {

  # ok if no missing deps
  my @miss=grep {$ARG &&! -f $ARG} @$deps;
  return if ! @miss;

  # ^give errme
  errout(
    "%s missing dependencies:%s\n",

    args=>[
      Shb7::shpath($self->{src}),
      prepend("\n::",@miss),

    ],

    lvl=>$AR_FATAL,

  );

};


# ---   *   ---   *   ---
# pre-build step

sub prebuild($self) {
  unlink $self->{obj} if -f $self->{obj};

  my $pproc=$self->{bk}->{pproc};

  $pproc->prebuild($self)
  if defined $pproc;

  return;

};


# ---   *   ---   *   ---
# ^post-build

sub postbuild($self) {
  my $pproc=$self->{bk}->{pproc};

  $pproc->postbuild($self)
  if defined $pproc;

  return;

};


# ---   *   ---   *   ---
# ^filters out multi-out source

sub binfilter($self) {
  my $pproc=$self->{bk}->{pproc};

  $pproc->binfilter($self)
  if defined $pproc;

  return;

};


# ---   *   ---   *   ---
# give list of paths

sub unroll($self,@keys) {
  return map {$self->{$ARG}} @keys;

};


# ---   *   ---   *   ---
1; # ret
