#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD
# Protos used often
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Carp qw(croak longmess);
  use Cwd qw(abs_path);

  use File::Spec;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    $O_RD
    $O_WR
    $O_EX

    $O_FILE
    $O_STR

  );

# ---   *   ---   *   ---
# ROM

  Readonly our $O_RD  =>0x0004;
  Readonly our $O_WR  =>0x0002;
  Readonly our $O_EX  =>0x0001;

  # just so we don't have to
  # -e(name) && -f(name) every single time
  Readonly our $O_FILE=>0x0008;
  Readonly our $O_STR =>0x0010;

# ---   *   ---   *   ---

sub building() {return exists $INC{'MAM.pm'}};

# ---   *   ---   *   ---
# in: filepath
# get name of file without the path

sub basename($path) {
  my @names=split m[/],$path;
  return $names[$#names];

};

# ^ removes extension(s)
sub nxbasename($path) {
  my $name=basename($path);
  $name=~ s/\..*$//;

  return $name;

};

# ^ get dir of filename...
# or directory's parent

sub dirof($path) {

  my @names=split(m[/],$path);
  $path=join('/',@names[0..($#names)-1]);

  return abs_path($path);

};

# ^ oh yes
sub parof($path) {
  return dirof(dirof($path));

};

# ---   *   ---   *   ---
# reverse of basename;
# gives first name in path

sub basedir($path) {
  my @names=split '/',$path;
  return $names[0];

};

# ---   *   ---   *   ---

sub relto($par,$to) {
  my $full="$par$to";
  return File::Spec->abs2rel($full,$par);

};

# ---   *   ---   *   ---
# find hashkeys in list
# returns matches ;>

sub lfind($search,$l) {
  return [grep {exists $search->{$ARG}} @$l];

};

# ---   *   ---   *   ---

sub invert_hash($h,%O) {

  # defaults
  $O{duplicate}//=0;

# ---   *   ---   *   ---

  if($O{duplicate}) {
    %$h=(%$h,reverse %$h);

  } else {
    %$h=reverse %$h;

  };

  return $h;

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

sub hashcpy($src) {

  my $cpy={};
  for my $key(keys %$src) {
    $cpy->{$key}=$src->{$key};

  };

  return $cpy;

};

# ---   *   ---   *   ---
1; # ret
