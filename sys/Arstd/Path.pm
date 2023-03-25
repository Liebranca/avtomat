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

  use English qw(-no_match_vars);
  use Cwd qw(abs_path);

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

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# get name of file without the path

sub basef($path) {
  my @names=split m[/],$path;
  return $names[$#names];

};

# ^ removes extension(s)
sub nxbasef($path) {
  my $name=basef($path);
  $name=~ s/\..*$//;

  return $name;

};

# ^ get dir of filename...
# or directory's parent

sub dirof($path) {

  my @names=split(m[/],$path);
  $path=join(q[/],@names[0..($#names)-1]);

  my $out=abs_path($path);
  $out//=$path;

  return $out;

};

# ^ oh yes
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

sub relto($par,$to) {
  my $full="$par$to";
  return File::Spec->abs2rel($full,$par);

};

# ---   *   ---   *   ---

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
1; # ret
