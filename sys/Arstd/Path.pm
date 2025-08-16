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
  use Style qw(null);
  use Chk qw(is_null is_path is_file);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    extcl
    extwap
    extof

    basef
    nxbasef
    dirof
    parof
    based

    relto
    expand
    reqdir

    find_pkg
    find_subpkg
    to_pkg
    from_pkg

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.0';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# get name of file without the path
#
# [0]: byte ptr ; string
# [<]: byte ptr ; new string

sub basef {
  my @names=split qr{/},$_[0];
  return $names[$#names];

};


# ---   *   ---   *   ---
# ^removes extension(s)
#
# [0]: byte ptr ; string
# [<]: bool     ; string is not null
#
# [!]: overwrites input string

sub extcl {
  return 0 if is_null $_[0];

  my $re=qr{\..*$};
  $_[0]=~ s[$re][];

  return ! is_null $_[0];

};

sub nxbasef {
  my $path=shift;
  return basef extcl $path;

};


# ---   *   ---   *   ---
# ^get parent directory
#
# [0]: byte ptr ; string
# [<]: byte ptr ; new string

sub parof {
  my $path = shift;
  my %O    = @_;

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
#
# [0]: byte ptr ; string
# [<]: byte ptr ; new string

sub dirof {
  return (! -d $_[0])
    ? parof @_,i=>1
    : $_[0]
    ;

};


# ---   *   ---   *   ---
# reverse of basef;
# gives first name in path
#
# [0]: byte ptr ; string
# [<]: byte ptr ; new string

sub based {
  my @names=split qr{/},$_[0];
  return $names[0];

};


# ---   *   ---   *   ---
# shorten path
#
# [0]: byte ptr ; path
# [<]: bool     ; path is not null
#
# [!]: overwrites input path
# [*]: uses cwd by default

sub relto {
  return 0 if is_null $_[0];

  $_[0]=File::Spec->abs2rel($_[0],$_[1]);

  my $re=qr{/+};
  $_[0]=~ s[$re][/];

  return ! is_null $_[0];

};


# ---   *   ---   *   ---
# require directory
#
# ensures a given directory
# path exists

sub reqdir($path) {

  # sanity check the path!
  croak "<null> passed to reqdir"
  if ! is_null $path;

  croak "<$path> has invalid characters"
  if ! is_path $path;

  croak "<$path> is a file"
  if -f $path;

  mkpath($path) if ! -d $path;
  return;

};


# ---   *   ---   *   ---
# get file extension
#
# [0]: byte ptr ; fname
# [<]: byte ptr ; extension (new string)

sub extof {
  my ($have)=$_[0]=~ qr{.+\.([^\.]+)$}sm;
  return (! is_null $have) ? $have : null ;

};


# ---   *   ---   *   ---
# ^swap extensions
#
# [0]: byte ptr ; fname
# [1]: byte ptr ; extension
#
# [<]: input string is valid
# [!]: overwrites input string

sub extwap {
  return 0 if ! is_file $_[0];

  my $re=qr{[^\.]+$};
  $_[0]=~ s[$re][$_[1]]smg;

  return is_file $_[0];

};


# ---   *   ---   *   ---
# get file from package name
#
# [0]: byte ptr  ; string
# [1]: byte pptr ; paths to check
#
# [<]: byte ptr ; new string

sub find_pkg {
  my ($name,@path)=@_;
  @path=@INC if ! @path;

  my $fname=from_pkg($name);
  my ($fpath)=grep {
    $ARG=<$ARG$fname>;-f $ARG

  } @path;


  return $fpath;

};


# ---   *   ---   *   ---
# looks for pkg/*.pm in path
#
# [0]: byte ptr  ; path base
# [1]: byte ptr  ; file name
# [2]: byte pptr ; paths to check
#
# [<]: byte ptr ; new string

sub find_subpkg {
  my ($base,$name,@path)=@_;
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
#
# [0]: byte ptr  ; path base
# [1]: byte ptr  ; file name
#
# [<]: bool ; string is not null
#
# [!]: overwrites input string

sub to_pkg {
  return 0 if is_null $_[0];
  $_[1] //= null;

  my $beg    = qr{^.*/?$_[1]};
  my $fslash = qr{/};
  my $ext    = qr{\.pm$};

  $_[0]=~ s[$beg][$_[1]] if $_[1];
  $_[0]=~ s[$fslash][::]sxmg;

  $_[0]=~ s[$ext][];

  return ! is_null $_[0];

};


# ---   *   ---   *   ---
# ^iv/undo
#
# [0]: byte ptr  ; package name#
# [<]: bool      ; string is not null
#
# [!]: overwrites input string

sub from_pkg {
  return 0 if is_null $_[0];

  my $re=qr{::};
  $_[0]  =~ s[$re][/]g;
  $_[0] .=  '.pm';

  return ! is_null $_[0];

};


# ---   *   ---   *   ---
1; # ret
