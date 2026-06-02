#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO BK
# object-building backend
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::bk;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null nop no_match);
  use Chk qw(is_file);

  use Arstd::String qw(gsplit);
  use Arstd::Array qw(filter);
  use Arstd::Bin qw(moo);
  use Arstd::throw;

  use Shb7::Path qw(relto_root);
  use avto::bfile;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.6';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub src_ext {return no_match};
sub obj_ext {return 'o'};
sub dep_ext {return 'd'};
sub asm_ext {return 's'};

sub linkable {return 0};
sub depsmake {goto \&nop};


# ---   *   ---   *   ---
# constructor

sub new {
  my ($class,$px,%O)=@_;

  # defaults
  $O{pproc} //= undef;

  # make ice
  my $self=bless {
    file  => [],
    pproc => $O{pproc},

  },$class;

  # ^setup files and give
  $self->push_src($ARG)
  for $px->filepop($self->src_ext());

  return $self;
};

# ---   *   ---   *   ---
# add entry to build files

sub push_src {
  my ($self,$fpath)=@_;
  push @{$self->{file}},avto::bfile->new(
    $fpath,
    obj=>$self->obj_ext(),
    dep=>$self->dep_ext(),
    asm=>$self->asm_ext(),
  );
  return;
};


# ---   *   ---   *   ---
# get array of build files

sub bfiles {
  return @{$_[0]->{file}};
};


# ---   *   ---   *   ---
# placeholders

sub target {return null};
sub fbuild {return 0};
sub fdeps {return ()};
sub on_build {
  my ($bk,$sw)=@_;
  return $bk->updated();
};


# ---   *   ---   *   ---
# get all files that need rebuilding

sub updated {
  my ($bk)=@_;
  return grep {$bk->fupdated($ARG)} $bk->bfiles();
};


# ---   *   ---   *   ---
# ^get whether a specific file needs rebuilding

sub fupdated {
  my ($bk,$bfile)=@_;

  # if the dependency file doesn't exist,
  # then we know the file was never built
  return 1 if! is_file($bfile->{dep});

  # else perform standard dependency check
  my @deps=$bk->fdeps($bfile);
  return $bfile->depchk(\@deps);
};


# ---   *   ---   *   ---
# generates intermediate files
# for the provided compilation units

sub build {
  my ($bk,$sw,@bfile)=@_;

  # make objects and dependencies
  $bk->build_objects($sw,@bfile);
  $bk->depsmake($sw,@bfile);

  # give list of all files if output is a
  # linkable format
  my @link=($bk->linkable())
    ? $bk->bfiles()
    : ()
    ;

  # give the list of objects built,
  # and the list of files to link
  return {
    linkable => [@link],
    updated  => [@bfile],
  };
};


# ---   *   ---   *   ---
# default method for handling a list of
# build files

sub build_objects {
  my ($bk,$sw,@bfile)=@_;
  return map {
    $bk->log_fpath($ARG->{obj});
    ($bk->fbuild($sw,$ARG))
      ? 1
      : exit -1
      ;

  } @bfile;
};


# ---   *   ---   *   ---
# generate log message indicating
# that a specific file is being built

sub log_fpath {
  my ($bk,$fpath)=@_;
  relto_root($fpath);
  Log->substep($fpath);

  return;
};


# ---   *   ---   *   ---
1; # ret
