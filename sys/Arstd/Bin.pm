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
  use File::Spec;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_path is_file is_dir);
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    ot
    moo
    orc
    dorc
    xdorc
    owc
    errmute
    erropen

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# RAM

my $Cache={errmute=>undef};


# ---   *   ---   *   ---
# "older than"
# return a is older than b
#
# [0]: byte ptr ; dst
# [1]: byte ptr ; src
#
# [<]: bool ; dst older than src

sub ot {
  throw "<null> passed to ot"
  if is_null $_[0] || is_null $_[1];

  return (
      (is_file $_[0])
  &&  (is_file $_[1])

  &&! ((-M $_[0]) < (-M $_[1]))

  );

};


# ---   *   ---   *   ---
# "missing or older"
# file not found or file needs update
#
# [0]: byte ptr ; dst
# [1]: byte ptr ; src
#
# [<]: bool ; dstmissing or older than src

sub moo {
  throw "<null> passed to moo"
  if is_null $_[0] || is_null $_[1];

  return (! is_file $_[0]) || ot($_[0],$_[1]);

};


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
    ! ($ARG=~ qr{^\.\.?$})

  } readdir $dir;
  closedir $dir or throw $_[0];

  return @out;

};


# ---   *   ---   *   ---
# ^recursive/array variant
#
# [0]: byte ptr  ; dirname
# [1]: byte pptr ; options
#
# [<]: byte pptr ; list
# [*]: performs path expansion

sub xdorc {
  return ($_[0]) if is_file $_[0];
  my $path = shift;
  my %O    = @_;

  # defaults
  $O{-r} //= 0;

  # walk directories
  my @out = ();
  my @rem = ($path);

  while(@rem) {

    # perform expansion,
    # filter out directories,
    # then opendir
    my @have=map {
      dorc $ARG;

    } grep {
      is_dir $ARG;

    } (glob(shift @rem));

    # files to out
    unshift @out,grep {-f "$path/$ARG"} @have;

    # recurse?
    unshift @rem,grep {-d "$path/$ARG"} @have
    if $O{-r};

  };


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
