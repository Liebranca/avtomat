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
  use Style qw(null);
  use Chk qw(is_null is_file);

  use Arstd::String qw(cat cjag);
  use Arstd::Bin qw(moo);
  use Arstd::Path qw(dirof reqdir);
  use Arstd::throw;

  use Shb7::Path qw(relto_root);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub avtopath {
  return "$ENV{ARPATH}/avtomat/";
};


# ---   *   ---   *   ---
# cstruc

sub new($class,$fpath,$bk,%O) {
  $O{out}//=null;

  my $self=bless {
    bk  => $bk,

    src => $fpath,
    out => $O{out},

    obj => Shb7::Path::obj_from_src(
      $fpath,
      ext=>$O{obj_ext}
    ),
    dep => Shb7::Path::obj_from_src(
      $fpath,
      ext=>$O{dep_ext}
    ),
    asm => Shb7::Path::obj_from_src(
      $fpath,
      ext=>$O{asm_ext}
    ),

  },$class;

  return $self;
};


# ---   *   ---   *   ---
# build output is valid ld input

sub linkable($self) {
  my $re    = qr{Shb7::Bk::(?:cmam|flat)};
  my $class = ref $self->{bk};

  return int($class=~ $re);
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
  for(@$deps) {
    # found dep is updated?
    if(moo($self->{obj},$ARG)) {
      $$do_build=1;
      return;
    };
  };

  return;
};


# ---   *   ---   *   ---
# sanity check: dependency files exist

sub depchk($self,$deps) {
  # ok if no missing deps
  my @miss=grep {$ARG &&! is_file($ARG)} @$deps;
  return if ! @miss;

  # ^give errme
  my $rel=$self->{src};
  relto_root($rel);
  throw cat(
    "$rel missing dependencies:\n",
    cjag("\n::",@miss),
  );
};


# ---   *   ---   *   ---
# pre-build step

sub prebuild($self) {
  unlink $self->{obj} if is_file($self->{obj});

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
# ensures that all target directories
# for this file exist

sub ensure_outdirs {
  for(
    $_[0]->{asm},
    $_[0]->{obj},
    $_[0]->{dep},
    $_[0]->{out},
  ) {
    reqdir dirof $ARG
    if ! is_null($ARG) &&! -f $ARG;
  };
  return;
};


# ---   *   ---   *   ---
1; # ret
