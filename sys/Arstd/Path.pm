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
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd::Path;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match_vars);
  use Cwd qw(abs_path);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

  use File::Spec;

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
    force_path

    extof
    extwap

    find_pkg
    find_subpkg
    fname_to_pkg
    pkg_to_fname

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.6;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get name of file without the path

sub basef($path) {
  my @names=split m[/],$path;
  return $names[$#names];

};

# ---   *   ---   *   ---
# ^removes extension(s)

sub nxbasef($path) {
  my $name=basef($path);
  $name=~ s/\..*$//;

  return $name;

};

# ---   *   ---   *   ---
# ^get dir of filename...
# or directory's parent

sub dirof($path,%O) {

  $O{abs} //= 1;

  my @names=split(m[/],$path);
  $path=join(q[/],@names[0..($#names)-1]);

  my $out=($O{abs})
    ? abs_path($path)
    : $path
    ;

  $out//=$path;

  return $out;

};

# ---   *   ---   *   ---
# ^oh yes

sub parof($path) {
  return dirof(dirof($path));

};

# ---   *   ---   *   ---
# reverse of basef;
# gives first name in path

sub based($path) {
  my @names=split m[/],$path;
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
# ensures a given directory
# path exists

sub force_path($path) {
  ! -f $path or croak "<$path> is a file\n";
  `mkdir -p $path` if ! -d $path;

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

  my $out = $NULLSTR;

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

sub fname_to_pkg($fname,$base=$NULLSTR) {

  state $ext=qr{\.pm$};

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
