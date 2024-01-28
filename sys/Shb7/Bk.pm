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
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Bk;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::Re;

  use Shb7;
  use Shb7::Bfile;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $TARGET=>{
    x64=>0,
    x32=>1,

  };

# ---   *   ---   *   ---
# constructor

sub new($class,%O) {

  # defaults
  $O{pproc} //= undef;

  # make ice
  my $self=bless {

    files=>[],
    pproc=>$O{pproc},

  },$class;


  return $self;

};

# ---   *   ---   *   ---
# add entry to build files

sub push_src($self,$fpath) {

  push @{$self->{files}},

  Shb7::Bfile->new(

    $fpath,
    $self,

    obj_ext=>q[.o],
    dep_ext=>q[.d],
    asm_ext=>q[.s],

  );

  return $self->{files}->[-1];

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
  return @{$self->{files}};

};

# ---   *   ---   *   ---
# placeholders

sub target($self) {
  return $NULLSTR;

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

sub chkfdeps($self,$bfile) {

  my $do_build =
     (! -f $bfile->{obj})
  || Shb7::ot($bfile->{obj},$bfile->{src})
  ;

  my @deps     = $self->fdeps($bfile);

  # no missing deps
  $bfile->depchk(\@deps);

  # make sure we need to update
  $bfile->buildchk(\$do_build,\@deps);

  return $do_build;

};

# ---   *   ---   *   ---
# shorthands

sub get_updated($self) {

  return grep {
    $self->fupdated($ARG);

  } $self->bfiles();

};

sub build_objects($self,$bld) {

  for my $bfile($self->get_updated()) {
    $self->fbuild($bfile,$bld);

  };

};

# ---   *   ---   *   ---
1; # ret
