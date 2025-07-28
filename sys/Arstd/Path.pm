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
  use English;
  use Cwd qw(abs_path);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

  use File::Spec;
  use File::Path qw(mkpath);

  use parent 'St';


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    basef
    based
    nxbasef

    dirof
    parof

    relto

    expand_path
    reqdir

    extof
    extwap
    extcl

    find_pkg
    find_subpkg
    fname_to_pkg
    pkg_to_fname

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

my $PKG=__PACKAGE__;
St::vconst {
  FPATH_RE => qr{
    [/_A-Za-z\.]
    [/_A-Za-z0-9\-\.\:\@\%\$\&]+

  }x,

};


# ---   *   ---   *   ---
# get name of file without the path

sub basef($path) {
  my @names=split m[/],$path;
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
  my @names=split $FSLASH_RE,$full;

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
  my @names=split $FSLASH_RE,$_[0];
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

sub expand_path($src,$dst) {

  my @ar;
  if(length ref $src) {@ar=(@{$src})}
  else {@ar=($src)};

  while(@ar) {
    my $path=shift @ar;
    if(-f $path) {unshift @$dst,$path;next};

    my @tmp=split m/\s+/,`ls $path`;

    unshift @$dst,(map {$path.q{/}.$ARG} @tmp);

  };

};


# ---   *   ---   *   ---
# require directory
#
# ensures a given directory
# path exists

sub reqdir($path) {

  # sanity check the path!
  defined $path or croak "undef passed to reqdir";
  length  $path or croak "<null> passed to reqdir";

  $path=~ $PKG->FPATH_RE
  or croak "<$path> has invalid characters";

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

  my $fname = pkg_to_fname($name);

  my ($fpath)=
    grep {-f $ARG}
    map  {<$ARG$fname>} @path;


  return $fpath;

};


# ---   *   ---   *   ---
# looks for pkg/*.pm in path

sub find_subpkg($base,$name,@path) {

  state $ext=qr{\.pm$};

  @path=@INC if ! @path;

  my $out = null;

  my $beg = ($base)
    ? qr{^.*/?$base}
    : null
    ;

  my $end = qr{$name}i;
  my $re  = (length $beg)
    ? qr{$beg/?.*/$end$ext}
    : qr{$end$ext}
    ;

  # case-insensitive filename search!
  my ($fpath)=
    grep {"$ARG"=~ $re}
    map  {<$ARG$base/*>} @path;


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

sub fname_to_pkg($fname,$base=null) {

  state $ext=qr{\.pm$};
  return null if ! defined $fname;

  my $beg=qr{^.*/?$base};

  $fname=~ s[$beg][$base] if $base;
  $fname=~ s[$FSLASH_RE][::]sxmg;

  $fname=~ s[$ext][];

  return $fname;

};


# ---   *   ---   *   ---
# ^iv/undo

sub pkg_to_fname($pkg) {
  $pkg=~ s[$DCOLON_RE][/]g;
  return "$pkg.pm";

};


# ---   *   ---   *   ---
1; # ret
