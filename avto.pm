#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO
# build my builds
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(getcwd abs_path);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Chk qw(is_file);
  use Arstd::Bin qw(bash);
  use Arstd::rd;
  use Arstd::throw;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# entry point

sub import {
  # default dst to current dir
  my ($class,$dirpath,@opt)=@_;
  $dirpath //= getcwd();

  # expand dirpath and validate
  ($dirpath)=abs_path(glob($dirpath));
  throw "avto: target '$dirpath' is a file -- "
  .     "a DIRECTORY is required"

  if    is_file($dirpath);

  # shorten names
  my $cfg="$dirpath/avto.cfg";
  my $bld="$dirpath/avto";

  # make sure avto.cfg exists in this directory
  throw "avto: no *.cfg file found at '$dirpath'"
  if!   is_file($cfg);

  # run module update?
  my $update=int grep {$ARG eq '-u'} @opt;

  Avt::config({rd($cfg),fpath=>$cfg})
  if $update ||! is_file($bld);

  # ^catch fail
  throw "avto: module update failed"
  if!   is_file($bld);

  # build module and give
  return bash($bld,@opt);
};


# ---   *   ---   *   ---
1; # ret
