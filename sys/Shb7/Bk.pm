#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7 BK
# Object-building backend
# base class
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Bk;
  use v5.42.0;
  use strict;
  use warnings;

  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

  use Arstd::Array;
  use Arstd::Re;

  use Shb7;
  use Shb7::Bfile;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.3';
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  TARGET => {
    x64=>0,
    x32=>1,

  },

};

# ---   *   ---   *   ---
# constructor

sub new($class,%O) {

  # defaults
  $O{pproc} //= undef;

  # make ice
  my $self=bless {
    file  => [],
    pproc => $O{pproc},

  },$class;


  return $self;

};

# ---   *   ---   *   ---
# add entry to build files

sub push_src($self,$fpath) {
  push @{$self->{file}},Shb7::Bfile->new(
    $fpath,
    $self,

    obj_ext=>q[.o],
    dep_ext=>q[.d],
    asm_ext=>q[.s],

  );

  return $self->{file}->[-1];

};

# ---   *   ---   *   ---
# gives dependency file list from str

sub depstr_to_array($self,$depstr) {

  # make list
  my @out=Lang::re_sursplit(
    $COMMA_RE,$depstr,sur=>'\s*'

  );

  # ensure there are no blanks
  array_filter(\@out);

  return @out;

};

# ---   *   ---   *   ---
# get array of build files

sub bfiles($self) {
  return @{$self->{file}};

};

# ---   *   ---   *   ---
# placeholders

sub target($self) {
  return null;

};

sub fbuild($self,$bfile,$bld) {
  return 0;

};

sub fupdated($self,$bfile) {
  return 1;

};

sub fdeps($self,$bfile) {
  return ();

};

# ---   *   ---   *   ---
# common fupdated proto

sub chkfdeps($self,$bfile,%O) {

  my $do_build =
     (! -f $bfile->{obj})
  || Shb7::ot($bfile->{obj},$bfile->{src})
  ;

  my @deps=$self->fdeps($bfile);

  # no missing deps
  $bfile->depchk(\@deps);

  # make sure we need to update
  $bfile->buildchk(\$do_build,\@deps,%O);

  return $do_build;

};

# ---   *   ---   *   ---
# shorthands

sub get_updated($self,%O) {

  return grep {
    $self->fupdated($ARG,%O);

  } $self->bfiles();

};

sub build_objects($self,$bld) {
  my %O=(
    clean=>$bld->{clean},
    debug=>int grep {
      $ARG eq '-g'

    } @{$bld->{flag}},

  );

  for my $bfile($self->get_updated(%O)) {
    $self->fbuild($bfile,$bld);

  };

};


# ---   *   ---   *   ---
1; # ret
