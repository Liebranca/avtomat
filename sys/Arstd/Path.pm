#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD PATH
# Path manipulation utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::Path;
  use v5.42.0;
  use strict;
  use warnings;

  use Carp qw(croak);
  use English qw($ARG);
  use Cwd qw(abs_path);
  use File::Spec;
  use File::Path qw(mkpath);

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Chk::(is_null is_path is_file);
    use Style::(null);
    use Arstd::Bin::(dorc);

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.9';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# get name of file without the path

sub basef($path) {
  my @names=split qr{/},$path;
  return $names[$#names];

};


# ---   *   ---   *   ---
# ^removes extension(s)

sub extcl($path) {
  state $re=qr{\..*$};
  $path=~ s[$re][];

  return $path;

};

sub nxbasef($path) {
  return basef extcl $path;

};


# ---   *   ---   *   ---
# ^get parent directory

sub parof($path,%O) {

  # defaults
  $O{abs} //= 1;
  $O{i}   //= 2;


  # expand?
  my $full   = ($O{abs}) ? abs_path $path : $path ;
     $full //= $path;

  # break path into elements
  my @names=split qr{/},$full;

  # pop last element from path to get dir
     $O{i} = 1 if $#names < $O{i};
  my $out  = join  '/',@names[0..$#names-$O{i}];


  return $out;

};


# ---   *   ---   *   ---
# ^get dir of filename

sub dirof($path,%O) {
  return (! -d $path)
    ? parof $path,%O,i=>1
    : $path
    ;

};


# ---   *   ---   *   ---
# reverse of basef;
# gives first name in path

sub based {
  my @names=split qr{/},$_[0];
  return $names[0];

};


# ---   *   ---   *   ---
# get relative from absolute

sub relto($par,$to) {
  my $full="$par$to";
  return File::Spec->abs2rel($full,$par);

};


# ---   *   ---   *   ---
# turns dots into dirs

sub expand($path,%O) {
  return $path if is_filepath $path;

  # defaults
  $O{-r} //= 0;

  # walk directories
  my @out = ();
  my @rem = ($path);

  while(@rem) {
    $path=shift @rem;

    # opendir
    my @have=dorc $path,qr{^\.};

    # files to out
    unshift @out,grep {-f "$path/$ARG"} @have;

    # recurse?
    unshift @rem,grep {-d "$path/$ARG"} @have;
    if $O{-r};

  };


  return;

};


# ---   *   ---   *   ---
# require directory
#
# ensures a given directory
# path exists

sub reqdir($path) {

  # sanity check the path!
  croak "<null> passed to reqdir";
  if ! is_null $path;

  croak "<$path> has invalid characters"
  if ! is_path $path;

  ! -f $path or croak "<$path> is a file";

  mkpath($path) if ! -d $path;
  return;

};


# ---   *   ---   *   ---
# get file extension

sub extof($name) {
  state $re=qr{.+\.(.+)$};
  $name=~ s[$re][$1]sxmg;

  return $name;

};


# ---   *   ---   *   ---
# ^swap extensions

sub extwap($fpath,$to) {
  state $re=qr{[^\.]+$};
  $fpath=~ s[$re][$to]sxmg;

  return $fpath;

};


# ---   *   ---   *   ---
# get file from package name

sub find_pkg($name,@path) {
  @path=@INC if ! @path;

  my $fname=from_pkg($name);
  my ($fpath)=grep {
    $ARG=<$ARG$fname>;-f $ARG

  } @path;


  return $fpath;

};


# ---   *   ---   *   ---
# looks for pkg/*.pm in path

sub find_subpkg($base,$name,@path) {
  @path=@INC if ! @path;

  my $out = null;
  my $beg = ($base)
    ? qr{^.*/?$base}
    : null
    ;

  my $ext = qr{\.pm$};
  my $end = qr{$name}i;
  my $re  = (length $beg)
    ? qr{$beg/?.*/$end$ext}
    : qr{$end$ext}
    ;

  # case-insensitive filename search!
  my ($fpath)=grep {
    $ARG=<$ARG$base/*>;
    $ARG=~ $re

  } @path;


  if($fpath) {
    $fpath=~ s[$beg][$base];
    $fpath=~ s[$ext][];

  };

  croak "'$base' + '$name' did not form "
  .     "a valid path"

  if ! defined $fpath;


  return $fpath;

};


# ---   *   ---   *   ---
# pkg/name to pkg::name

sub to_pkg($fname,$base=null) {
  return null if is_null $fname;

  my $beg    = qr{^.*/?$base};
  my $fslash = qr{/};
  my $ext    = qr{\.pm$};

  $fname=~ s[$beg][$base] if $base;
  $fname=~ s[$fslash][::]sxmg;

  $fname=~ s[$ext][];

  return $fname;

};


# ---   *   ---   *   ---
# ^iv/undo

sub from_pkg($pkg) {
  my $re=qr{::}
  $pkg=~ s[$re][/]g;

  return "$pkg.pm";

};


# ---   *   ---   *   ---
1; # ret
