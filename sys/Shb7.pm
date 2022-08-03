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
package Shb7;

  use v5.36.0;
  use strict;
  use warnings;

  use Storable;
  use Readonly;

  use Cwd qw(abs_path getcwd);

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

  use Tree::File;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.0;
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

    $Root,
    $Cache,

    $Trash,
    $Root_Re

  );

# ---   *   ---   *   ---
# ^setter

sub set_root($path) {
  $Root=abs_path(pathchk($path));

  if(!($Root=~ $F_SLASH_END)) {
    $Root.=q[/];

  };

  $Cache="$Root.cache/";
  $Trash="$Root.trash/";

  $Root_Re=qr{^(?: $DOT_BEG /? | $Root)}x;

  return $Root;

};

# ---   *   ---   *   ---

sub pathchk($path) {

  my $cpy=glob($path);
  $cpy//=$path;

  if(!defined $cpy) {

    Arstd::errout(

      q{Uninitialized path '%s'}."\n".

      q{cwd   %s}."\n".
      q{root  %s},

      args=>[$path,getcwd(),$Root],
      lvl=>$AR_FATAL,

    );

  };

# ---   *   ---   *   ---

  if( !(-e $cpy)
  &&  !(-e "$Root/$cpy")

  ) {

    Arstd::errout(

      q{Invalid file or directory '%s'}."\n".

      q{cwd   %s}."\n".
      q{root  %s},

      args=>[$path,getcwd(),$Root],
      lvl=>$AR_FATAL,

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

sub file($path) {return $Root.$path};

sub dir($path=$NULLSTR) {
  return $Root.$path.q{/};

};

sub obj_file($path) {return $Trash.$path};

sub obj_dir($path=$NULLSTR) {
  return $Trash.$path.q{/}

};

# ---   *   ---   *   ---
# shortcuts for finding things on main lib dir
# i'll couple it with a file search later

sub lib($name=$NULLSTR) {return $Root."lib/$name"};
sub so($name) {return $Root."lib/lib$name.so"};

sub cache_file($name) {return $Cache.$name};

# ---   *   ---   *   ---
# gives object file path from source file path

sub obj_from_src($src) {

  my $o=$src;

  $o=~ s/$Root_Re/$Trash/;
  $o=~ s/\.[\w|\d]*$/\.o/;

  return $o;

};

# ---   *   ---   *   ---
# gives path relative to current root

sub rel($path) {

#:!;> dirty way to do it without handling
#:!;> the obvious corner case of ..

  $path=~ s[$Root_Re][./];
  return $path;

};

# ---   *   ---   *   ---
# tells you which module within $Root a
# given file belongs to

sub module_of($file) {
  return Arstd::basedir(shpath($file));

};

# ---   *   ---   *   ---
# shortens pathname for sanity

sub shpath($path) {
  $path=~ s[$Root_Re][];
  return $path;

};

# ---   *   ---   *   ---
# inspects a directory within root

sub walk($path,%O) {

  # defaults
  $O{-r}//=0;
  $O{-x}//=[];

# ---   *   ---   *   ---
# build exclusion re

  $O{-x}=join q{|},@{$O{-x}};
  if(length $O{-x}) {$O{-x}.=q{|}};

  $O{-x}.=q{
    nytprof | data | docs | tests

  };

  $O{-x}=qr{(?:$O{-x})}x;

# ---   *   ---   *   ---

  my $frame=Tree::File->new_frame();
  my $root_node=undef;

  my @pending=(dir($path),undef);
  my $out=undef;

# ---   *   ---   *   ---
# prepend and open

  while(@pending) {

    $path=shift @pending;
    $root_node=shift @pending;

    my $dst=(!defined $root_node)
      ? $frame->nit($root_node,$path)
      : $root_node

      ;

    $out//=$dst;

    # errchk
    if(!(-d $path)) {

      Arstd::errout(

        q{Is not a directory '%s'},

        args=>[$path],
        lvl=>$AR_FATAL,

      );

    };

# ---   *   ---   *   ---
# go through the entries

    opendir my $dir,$path or croak strerr($path);

    my @files=readdir $dir;

    my $key=Arstd::basename($path);
    $dst->{$key}={};

# ---   *   ---   *   ---
# skip .dotted or excluded

    for my $f(@files) {
    next if $f=~ m[ $DOT_BEG | $O{-x}]x;

# ---   *   ---   *   ---
# filter out files from dirs

      if(-f "$path/$f") {
        $frame->nit($dst,$f);

      } elsif(($O{-r}) && (-d "$path$f/")) {
        unshift @pending,

          "$path$f/",
          $frame->nit($dst,"$f/")

        ;

      };

# ---   *   ---   *   ---

    };

    closedir $dir or croak strerr($path);

  };

  return $out;

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
  my $path=cache_file($pkg.q{::}.$name);

  my $out={};

  if(Shb7::missing_or_older(
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
