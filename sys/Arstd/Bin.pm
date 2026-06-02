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

  use Storable qw(freeze thaw);
  use Cwd qw(abs_path);
  use English qw($ARG);
  use File::Spec;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null no_match);
  use Chk qw(
    is_null
    is_path
    is_file
    is_dir
  );
  use Arstd::Array qw(filter);
  use Arstd::String qw(strip gsplit);
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
    nuke
    owc
    opc
    xclip
    bash
    perl
    errmute
    erropen
    deepcpy

    cpuinfo
    cpuflag
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.4';
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
  # we get out early if the path to an
  # _actual_ file was passed as that can't
  # be expanded
  return ($_[0]) if is_file($_[0]);

  # else we take args
  my $path = shift;
  my %O    = @_;

  # defaults
  $O{-f} //= 0;
  $O{-r} //= 0;
  $O{-d} //= 0;
  $O{-x} //= no_match;

  # walk directories
  my @out = ();
  my @rem = (glob($path));

  while(@rem) {
    $path=shift @rem;

    # opendir on each directory and filter
    # out results that match the exclusion pattern
    my @have=(
      map  {"$path/$ARG"}
      grep {! ($ARG=~ $O{-x})} dorc($path)
    );

    # save to out
    my @dir=grep {is_dir($ARG)} @have;
    unshift @out,grep {is_file($ARG)} @have;
    unshift @out,@dir if $O{-d};

    # recurse?
    unshift @rem,@dir if $O{-r};
  };

  # need to give absolute paths?
  if($O{-f}) {
    $ARG=abs_path($ARG) for @out;
  };

  # give list of files
  return @out;
};


# ---   *   ---   *   ---
# removes files from directory
#
# [0]: byte ptr  ; path to dir
# [1]: byte pptr ; [option => value] array
#
# [*]: does not recurse by default

sub nuke {
  my $path = shift;
  my %O    = @_;

  # this ensures directories aren't
  # destroyed by this F, not by default
  $O{-d} //= 0;
  $O{-r} //= 0;

  my @have=xdorc($path,%O,-f=>1);

  # now wipe it off the face of the... disk
  filter(\@have);
  unlink($ARG) for grep {is_file($ARG)} @have;
  rmdir($ARG)  for grep {is_dir($ARG)}  @have;

  return;
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
# open,pipe,close
#
# [0]: byte ptr ; cmd plus args
# [1]: byte ptr ; buf to write
#
# [<]: qword ; bytes written

sub opc {
  open my $fh,'|-',$_[0] or throw $_[0];
  my $wr=print {$fh} $_[1];
  close $fh or throw $_[0];

  return $wr*length $_[1];
};


# ---   *   ---   *   ---
# ^ real talk for a minute,
#   *this* is the real reason that
#   opc even exists ;>
#
# [0]: byte ptr ; string to copy to clipboard
# [<]: qword    ; bytes written

sub xclip {
  return opc('xclip -selection c',$_[0]);
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
# selfex

sub deepcpy {
  return thaw(freeze($_[0]));
};


# ---   *   ---   *   ---
# run command
#
# [0]: byte pptr ; command [args]
# [<]: 0 or throw
#
# [!]: stops execution on fail

sub bash {
  use English qw($CHILD_ERROR);

  print `@_`;
  exit  -1 if $CHILD_ERROR;

  return 0;
};


# ---   *   ---   *   ---
# ^run perl script!

sub perl {
  my ($file,@argv)=@_;
  $file //= '<null>';

  throw "perl: can't do '$file'"
  if!   is_file($file);

  # force reload
  delete $INC{$file};

  # this lets us read args through ARGV,
  # as we normally would
  local @ARGV=@argv;
  do $file or throw $@;

  return 0;
};


# ---   *   ---   *   ---
# reads cpuinfo file and parses
# it into a hash

sub cpuinfo {
  # this F always gives the same result,
  # so it's appropriate to cache it
  state $cache=null;
  return $cache if! is_null($cache);

  # get [key]:[value] for each line in
  # the cpuinfo file
  my $out  = {};
  my $re   = qr{^\s*(?<name>[^:]+?)\s*:};
  my @line = gsplit(orc("/proc/cpuinfo"),qr"\n");

  for(@line) {
    # detect error, though if this is incorrect
    # then i reckon we have bigger problems ;>
    throw "cpuinfo: faulty line '$ARG'"
    if!   ($ARG=~ s[$re][]);

    # give key=>[value]
    my $name=$+{name};
    strip($name);

    $out->{$name}=[gsplit($ARG,qr"\s+")];
  };

  # cache result and give
  $cache=$out;
  return $out;
};


# ---   *   ---   *   ---
# ^ checks whether there's a given
#   flag in cpuinfo

sub cpuflag {
  my ($flag)=@_;
  my $info=cpuinfo();

  return int grep {$flag eq $ARG} @{$info->{flags}};
};


# ---   *   ---   *   ---
1; # ret
