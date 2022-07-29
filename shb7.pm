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

  use Storable;
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

  our $F_SLASH_END;
  our $DOT_BEG;

# ---   *   ---   *   ---

BEGIN {

  $F_SLASH_END=qr{/$}x;
  $DOT_BEG=qr{^\.}x;

};

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

  if(!($root=~ $F_SLASH_END)) {
    $root.=q[/];

  };

  $cache="$root.cache/";
  $trash="$root.trash/";

  $root_re=qr{^(?: $DOT_BEG /? | $root)}x;

  return $root;

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

BEGIN {
  set_root(
    abs_path($ENV{'ARPATH'})

  );

};

# ---   *   ---   *   ---
# these are just for readability
# we could add checks though...

sub file($path) {return $root.$path};

sub dir($path=$NULLSTR) {
  return $root.$path.q{/};

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
# gives path relative to current root

sub rel($path) {

#:!;> dirty way to do it without handling
#:!;> the obvious corner case of ..

  $path=~ s[$root_re][./];
  return $path;

};

# ---   *   ---   *   ---
# tells you which module within $root a
# given file belongs to

sub module_of($file) {
  return arstd::basedir(shpath($file));

};

# ---   *   ---   *   ---
# shortens pathname for sanity

sub shpath($path) {
  $path=~ s[$root_re][];
  return $path;

};

# ---   *   ---   *   ---
# inspects a directory within root

sub walk($path,%O) {

  # defaults
  $O{-r}//=0;
  $O{-x}//=q{
    (?: nytprof | data | docs)

  };

  $O{-x}=qr{$O{-x}}x;

  my $table=[{}];

  my $beg=dir($path);
  my @pending=($beg,$table->[0]);

# ---   *   ---   *   ---
# prepend and open

  while(@pending) {

    $path=shift @pending;
    my $dst=shift @pending;

    # errchk
    if(!(-d $path)) {

      arstd::errout(

        q{Is not a directory '%s'},

        args=>[$path],
        lvl=>$FATAL,

      );

    };

# ---   *   ---   *   ---
# go through the entries

    opendir my $dir,$path or croak STRERR($path);

    my @files=readdir $dir;

    my $key=arstd::basename($path);
    $dst->{$key}=[{}];

# ---   *   ---   *   ---
# skip .dotted or excluded

    for my $f(@files) {
    next if $f=~ m[ $DOT_BEG | $O{-x}]x;

# ---   *   ---   *   ---
# filter out files from dirs

      if(-f "$path/$f") {
        push @{$dst->{$key}},$f;

      } elsif(($O{-r}) && (-d $f)) {
        unshift @pending,
          $beg.$f,$dst->{$key}->[0];

      };

# ---   *   ---   *   ---

    };

    closedir $dir or croak STRERR($path);

  };

  return $table;

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
# loads a file if available
# else regenerates it from a sub

sub load_cache($name,$dst,$call,@args) {

  my ($pkg,$fname,$line)=(caller);
  my $path=shb7::cache_file($pkg.q{::}.$name);

  my $out={};

  if(shb7::missing_or_older(
    $path,abs_path($fname))

  ) {

    print {*STDERR}

      'updated ',"\e[32;1m",
      shpath($path),

      "\e[0m\n"

    ;

    $out=$call->(@args);
    store($out,$path);

  } else {
    $out=retrieve($path);

  };

  $$dst=$out;

};

# ---   *   ---   *   ---
1; # ret
