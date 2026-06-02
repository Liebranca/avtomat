#!/usr/bin/perl
# ---   *   ---   *   ---
# BK FLAT
# Wrappers for fasm+ld ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::bk::flat;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_file);

  use Arstd::String qw(gsplit);
  use Arstd::Path qw(extwap);
  use Arstd::Bin qw(orc);
  use Arstd::throw;

  use Shb7::Path qw(relto_root);

  use Log;

  use lib "$ENV{ARPATH}/lib/sys/";
  use AR;
  use parent 'avto::bk';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.6';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub obj_ext {return 'o'};
sub dep_ext {return 'asmd'};
sub asm_ext {return null};


# ---   *   ---   *   ---
# get file dependencies

sub fdeps {
  my ($bk,$bfile)=@_;
  my @out=($bfile->{src});

  # early exit if no dependency file
  return @out if! is_file($bfile->{dep});

  # ^else file and give
  my $body=orc($bfile->{dep});
  return gsplit($body,qr"\n");
};


# ---   *   ---   *   ---
# wrapper for the standard method,
# as fasm requires that we setup
# the include paths as an environ

sub build_objects {
  my ($bk,$sw,@bfile)=@_;

  # get paths from shell ghost
  my @inc=(
    @{Shb7::Path::include()},
    @{Shb7::Path::lib()}
  );

  # ^save previous JIC and set new
  my $old="$ENV{INCLUDE}";

  $ENV{INCLUDE}=join(';',$old,@inc);
  my @out=avto::bk::build_objects($sw,@bfile);

  # ^restore and give
  $ENV{INCLUDE}=$old;
  return @out;
};


# ---   *   ---   *   ---
# object file boiler

sub fbuild {
  my ($bk,$sw,$bfile)=@_;

  # assemble and catch fail
  my @args=();
  my @call=qw(fasm2=>@args=>$bfile->{src});
  filter(\@call);
  system {$call[0]} @call;

  my $out=extwap($bfile->{src},'o');
  return 0 if! is_file($out);

  # ^else reloc out and give
  rename $out,$bfile->{obj};
  return 1;
};


# ---   *   ---   *   ---
1; # ret
