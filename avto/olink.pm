#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO OLINK
# objects galore
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::olink;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(getcwd);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_file);
  use Log;

  use Arstd::Array qw(filter iof);
  use Arstd::Path qw(reqdir dirof);
  use Arstd::Bin qw(owc);
  use Arstd::throw;

  use lib "$ENV{ARPATH}/lib/";
  use avto::switch;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(olink);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.2';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# entry point

sub olink {
  my ($px,$sw,@obj)=@_;

  # nothing to do?
  return Log->step("no linking needed")
  if!    @obj;

  # else validate
  my @miss=grep {! is_file($ARG)} @obj;
  if(@miss) {
    Log->step("missing file $ARG") for @miss;
    throw "olink: aborted";
  };

  # get linking method and run
  my @call=($px->{fflat})
    ? olink_use_ld($sw,@obj)
    : oling_use_gcc($sw,@obj)
    ;

  filter(\@call);
  system {$call[0]} @call;

  return is_file($sw->{output});
};


# ---   *   ---   *   ---
# link using gcc

sub olink_use_gcc {
  my ($sw,@obj)=@_;
  my ($linker,@link)=(
    map {"-Wl,$ARG"}
    avto::switch::ldget($sw)
  );
  $linker="-fuse-ld=$linker";

  return (
    "gcc",

    @{$sw->{arch}},
    @{$sw->{obc}},
    @{$sw->{inc}},

    $linker,
    @link,
    @obj,

    -o=>$sw->{output},

    @{$sw->{lib}},
  );
};


# ---   *   ---   *   ---
# link using ld

sub olink_use_ld($sw,@obj) {
  my ($linker,@link)=avto::switch::ldget($sw);
  return (
    "ld.$linker",

    @{$sw->{ldarch}},
    @link,

    -o=>$sw->{output},

    @obj,
    @{$sw->{lib}},
  );
};


# ---   *   ---   *   ---
1; # ret
