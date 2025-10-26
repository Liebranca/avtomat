#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7 BK FAKE
# Screw python until the
# end of time
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::fake;
  use v5.42.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use parent 'Shb7::Bk';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1b';
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub new($class,%O) {
  # make ice
  my $self=bless [],$class;
  return $self;
};


# ---   *   ---   *   ---
# add entry to build files

sub push_src($self,$fpath,$fout) {
  push @$self,
  Shb7::Bfile->new(
    $fpath,
    $self,

    out     => $fout,

    obj_ext => q[.py],
    dep_ext => q[.pyd],
    asm_ext => undef,

  );

  return $self->[-1];
};


# ---   *   ---   *   ---
# get array of build files

sub bfiles($self) {
  return @$self;
};


# ---   *   ---   *   ---
1; # ret
