#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7
# Shell utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb
# ---   *   ---   *   ---

# deps
package shb7;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Cwd qw(abs_path getcwd);

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $F_SLASH_AT_END=>qr{/$}x;

# ---   *   ---   *   ---
# global state

  our (

    $root,
    $cache,

    $trash,
    $root_re

  );

# ---   *   ---   *   ---
# ^setter

sub set_root($path) {
  $root=abs_path(pathchk($path));

  if(!($root=~ $F_SLASH_AT_END)) {
    $root.=q[/];

  };

  $cache="$root/.cache/";
  $trash="$root/.trash/";

  $root_re=qr{^(?: \./? | $root)}x;

  return $root;

};

INIT {set_root(abs_path($ENV{'ARPATH'}))};

# ---   *   ---   *   ---
# these are just for readability
# we could add checks though...

sub file($path) {return $root.$path};

sub dir($path=$NULLSTR) {
  return $root.$path.q{/}

};

sub obj_file($path) {return $trash.$path};

sub obj_dir($path=$NULLSTR) {
  return $trash.$path.q{/}

};

# ---   *   ---   *   ---
# shortcuts for finding things on main lib dir
# i'll couple it with a file search later

sub lib($name=$NULLSTR) {return $root."lib/$name"};
sub so($name) {return $root."lib/lib$name.so"};

sub cache_file($name) {return $cache.$name};

# ---   *   ---   *   ---
# gives object file path from source file path

sub obj_from_src($src) {

  my $o=$src;

  $o=~ s/$root_re/$trash/;
  $o=~ s/\.[\w|\d]*$/\.o/;

  return $o;

};

# ---   *   ---   *   ---

sub pathchk($path) {

  my $cpy=glob($path);
  $cpy//=$path;

  if(!defined $cpy) {

    arstd::errout(

      q{Uninitialized path '%s'}."\n".

      q{cwd   %s}."\n".
      q{root  %s},

      args=>[$path,getcwd(),$root],
      lvl=>$FATAL,

    );

  };

# ---   *   ---   *   ---

CHECK:

  if( !(-e $cpy)
  &&  !(-e "$root/$cpy")

  ) {

    arstd::errout(

      q{Invalid file or directory '%s'}."\n".

      q{cwd   %s}."\n".
      q{root  %s},

      args=>[$path,getcwd(),$root],
      lvl=>$FATAL,

    );

  };

  return $path;

};

# ---   *   ---   *   ---
# gives path relative to current root

sub root_rel($path) {

#:!;> dirty way to do it without handling
#:!;> the obvious corner case of ..

  $path=~ s[$root_re][./];
  return $path;

};

# ---   *   ---   *   ---
# shortens pathname for sanity

sub shpath($path) {
  $path=~ s[$root_re][];
  return $path;

};

# ---   *   ---   *   ---
#in: two filepaths to compare
# Older Than; return a is older than b

sub ot($a,$b) {
  return !( (-M $a) < (-M $b) );

};

# ^file not found or file needs update
sub missing_or_older($a,$b) {
  return !(-e $a) || ot($a,$b);

};

# ---   *   ---   *   ---

sub load_cache($f,$x) {

};

# ---   *   ---   *   ---
1; # ret
