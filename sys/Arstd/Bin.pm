#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD BIN
# Everything is a file!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::Bin;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG $ERRNO);
  use Carp qw(croak);
  use File::Spec;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.0';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# RAM

my $Cache={errmute=>undef};


# ---   *   ---   *   ---
# your hands in the air!

sub throw {
  $_[0] //= '<null>';
  croak "$ERRNO: '$_[0]'";

};


# ---   *   ---   *   ---
# open,read,close

sub orc($fname) {
  open  my $fh,'<',$fname or throw $fname;
  read  $fh,my $body,-s $fh;
  close $fh or throw $fname;

  return $body;

};


# ---   *   ---   *   ---
# directory open,read,close

sub dorc($path,$excluded=qr{\b\B}) {
  opendir my $dir,$path or throw $path;

  my @out=grep {
    ! (-d "$dir/$ARG/")
  &&! ($ARG=~ $excluded);

  } readdir $dir;
  closedir $dir or throw $path;

  return @out;

};


# ---   *   ---   *   ---
# open,write,close

sub owc($fname,$bytes) {
  open my $fh,'+>',$fname or throw $fname;
  my $wr=print {$fh} $bytes;
  close $fh or throw $fname;

  return $wr*length $bytes;

};


# ---   *   ---   *   ---
# mute stderr

sub errmute {
  my $fhref=\$Cache->{errmute};
  return if defined $$fhref;

  $$fhref=readlink "/proc/self/fd/2";

  open STDERR,'>',File::Spec->devnull()
  or throw '/dev/null';

  return;

};


# ---   *   ---   *   ---
# ^restore

sub erropen {
  my $fh=$Cache->{errmute};
  return if ! defined $fh;

  open STDERR,'>',$fh or throw $fh;
  return;

};


# ---   *   ---   *   ---
1; # ret
