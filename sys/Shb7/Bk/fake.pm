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
  use Shb7::Bk;

  use parent 'Shb7::Bk';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
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

  Shb7::Bfile->nit(

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
