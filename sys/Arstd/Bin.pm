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

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_path);
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    orc
    dorc
    owc
    errmute
    erropen

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.0';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# RAM

my $Cache={errmute=>undef};


# ---   *   ---   *   ---
# open,read,close
#
# [0]: byte ptr ; filename
# [<]: byte ptr ; file contents (new string)

sub orc {
  open  my $fh,'<',$_[0] or throw $_[0];
  read  $fh,my $body,-s $fh;
  close $fh or throw $_[0];

  return $body;

};


# ---   *   ---   *   ---
# directory open,read,close
#
# [0]: byte ptr  ; dirname
# [<]: byte pptr ; elems in dir (new array)
#
# [*]: excludes "." && "..", but not other
#      hidden files/dirs

sub dorc {
  opendir my $dir,$_[0] or throw $_[0];
  my @out=grep {
    ! ((-d $ARG) && ($ARG=~ qr{^\.\.?$}))

  } readdir $dir;
  closedir $dir or throw $_[0];

  return @out;

};


# ---   *   ---   *   ---
# open,write,close
#
# [0]: byte ptr ; dst filename
# [1]: byte ptr ; buf to write
#
# [<]: qword ; bytes written
#
# [!]: throws if filename has invalid chars
#      see Chk::is_path for details

sub owc {
  throw "Invalid filename: '$_[0]'"
  if ! is_path $_[0];

  open my $fh,'+>',$_[0] or throw $_[0];
  my $wr=print {$fh} $_[1];
  close $fh or throw $_[0];

  return $wr*length $_[1];

};


# ---   *   ---   *   ---
# (nihil) mute stderr
#
# [*]: previous filehandle is stored by
#      this package (and restored by it, too)
#
# [*]: does nothing if stderr already muted

sub errmute {
  my $fhref=\$Cache->{errmute};
  return if ! is_null $$fhref;

  $$fhref=readlink "/proc/self/fd/2";

  open STDERR,'>',File::Spec->devnull()
  or throw '/dev/null';

  return;

};


# ---   *   ---   *   ---
# (nihil) unmute stderr
#
# [*]: does nothing if stderr not muted

sub erropen {
  my $fh=$Cache->{errmute};
  return if is_null $fh;

  open STDERR,'>',$fh or throw $fh;
  return;

};


# ---   *   ---   *   ---
1; # ret
