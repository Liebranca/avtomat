#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO SHWL
# keeper of tabs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::shwl;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Storable qw(retrieve);

  use lib "$ENV{ARPATH}/lib/sys/";

  use Style qw(null);
  use Chk qw(is_null is_file);

  use Arstd::throw;
  use Shb7::Find qw(ffind);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub fext {return 'shwl'};


# ---   *   ---   *   ---
# search for shadow lib in path

sub find {
  my ($name)=@_;

  # existence check
  my $out  = null;
  my $path = ffind($name=>fext());
  goto skip if is_null($path);

  # all OK, go ahead
  $out=retrieve($path);

  throw "avto: error reading SHWL '$path'"
  if    is_null($out);

  # either there's no file, or we found one
  skip:
  return $out;
};


# ---   *   ---   *   ---
1; # ret
