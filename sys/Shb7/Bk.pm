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

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);

  use Arstd::Array qw(filter);
  use Arstd::throw;

  use Shb7::Bfile;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub target_arch {
  return 0 if $_[0] eq 'x64';
  return 1 if $_[0] eq 'x86';
  throw "Unknown target '$_[0]'";
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

    obj_ext=>'o',
    dep_ext=>'d',
    asm_ext=>'s',
  );

  return $self->{file}->[-1];
};


# ---   *   ---   *   ---
# gives dependency file list from str

sub depstr_to_array($self,$depstr) {
  # make list
  my @out=split qr{\*,\s*},$depstr;

  # ensure there are no blanks
  filter(\@out);

  return @out;
};


# ---   *   ---   *   ---
# get array of build files

sub bfiles($self) {
  return @{$self->{file}};
};


# ---   *   ---   *   ---
# placeholders

sub target($self) {return null};
sub fbuild($self,$bfile,$bld) {return 0};
sub fupdated($self,$bfile,%O) {return 1};
sub fdeps($self,$bfile) {return ()};
sub on_build($self,$bld,%O) {};


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
# generates intermediate files

sub build($self,$bld) {
  my %O=(
    clean=>$bld->{clean},
    debug=>int grep {
      $ARG eq '-g'

    } @{$bld->{flag}},
  );

  # get files to (re)build
  my @bfile=$self->get_updated(%O);
  $ARG->ensure_outdirs() for @bfile;

  # this is so each backend can have
  # its own pre-build hook
  $self->on_build($bld);

  # get total number of objects that were built
  my $cnt=int grep(
    $ARG,$self->build_objects($bld,@bfile)
  );

  # get list of files that are linkable,
  # whether they were built or not
  my @link=grep {$ARG->linkable()} $self->bfiles();

  # ^give number of objects built plus that list
  return ($cnt,@link);
};


# ---   *   ---   *   ---
# get files that need rebuilding

sub get_updated($self,%O) {
  return grep {
    $self->fupdated($ARG,%O);

  } $self->bfiles();
};


# ---   *   ---   *   ---
# default method for handling a list of
# build files

sub build_objects($self,$bld,@bfile) {
  return map {
    $self->log_fpath($ARG->{src});
    $self->fbuild($ARG,$bld);

  } @bfile;
};


# ---   *   ---   *   ---
# generate log message indicating
# that a specific file is being built

sub log_fpath {
  my ($self,$fpath)=@_;
  relto_root($fpath);
  Log->substep($fpath);

  return;
};


# ---   *   ---   *   ---
1; # ret
