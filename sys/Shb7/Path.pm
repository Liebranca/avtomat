#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7 PATH
# Search directory lists
# and associated shortcuts
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Path;

  use v5.36.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path getcwd);

  use English qw(-no_match_vars);
  use Readonly;

  use Exporter 'import';

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Path;
  use Arstd::IO;

  use Tree::File;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# adds to your namespace

  our @EXPORT=qw(

    set_root
    set_module

    clear_includes
    clear_libs

    push_includes
    push_libs

    set_includes
    set_libs

    file
    dir

    lib
    libdir
    so

    cache
    mem
    trash

    modof
    shpath

    rel
    ot
    moo
    walk

    obj_from_src

    $INCL_RE
    $LIBD_RE
    $LIBF_RE
    $WILDCARD_RE
    $ANYEXT_RE

  );

# ---   *   ---   *   ---
# ROM

  our $F_SLASH_END;
  our $DOT_BEG;

  Readonly our $INCL_RE=>qr{^\s*\-I}x;
  Readonly our $LIBD_RE=>qr{^\s*\-L}x;
  Readonly our $LIBF_RE=>qr{^\s*\-l}x;

  Readonly our $WILDCARD_RE=>qr{\%};

  Readonly our $ANYEXT_RE=>qr{\.[\w|\d]+$};

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
    $Config,
    $Mem,

    $Root_Re,

    $Lib,
    $Include,

    $Cur_Module,

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
  $Mem="$Root.mem/";
  $Config="$Root.config/";

  mkdir $Config if ! -e $Config;

  $Lib//=[];
  $Include//=[];

  $Lib->[0]="${Root}lib/";

  $Include->[0]=$Root;
  $Include->[1]="${Root}include/";

  $Root_Re=qr{^(?: $DOT_BEG /? | $Root)}x;
  $Cur_Module=$NULLSTR;

  return $Root;

};

# ---   *   ---   *   ---
# pathchk errme n0

sub throw_undef_path($path) {

  errout(

    q{Uninitialized path passed in}."\n".

    q{cwd   %s}."\n".
    q{root  %s},

    args => [getcwd(),$Root],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# pathchk errme n0

sub throw_bad_path($path) {

  errout(

    q{Invalid file or directory '%s'}."\n".

    q{cwd   %s}."\n".
    q{root  %s},

    args => [$path,getcwd(),$Root],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# sanity check

sub pathchk($path) {

  my $cpy=glob($path);
  $cpy//=$path;

  if(!defined $cpy) {
    throw_undef_path()

  } elsif(

     !(-e $cpy)
  && !(-e "$Root/$cpy")

  ) {

    throw_bad_path($path);

  };

  return $path;

};

# ---   *   ---   *   ---
# sets default topdir

BEGIN {

  set_root(
    abs_path($ENV{'ARPATH'})

  );

};

# ---   *   ---   *   ---
# mark mod as current

sub set_module($name) {

  my $path=dir($name);

  errout(
    q[No such directory <%s>],

    args => [$path],
    lvl  => $AR_FATAL

  ) unless -d $path;

  $Cur_Module=$name;

};

# ---   *   ---   *   ---
# SEARCH PATH SETTERS

# ---   *   ---   *   ---
# wipe out

sub clear_includes(@args) {
  $Include=[];

};

sub clear_libs(@args) {
  $Lib=[];

};

# ---   *   ---   *   ---
# add to

sub push_includes(@args) {

  for my $path(@args) {

    $path=~ s[$INCL_RE][];
    $path=abs_path(glob($path));

    push @$Include,$path;

  };

};

sub push_libs(@args) {

  for my $path(@args) {

    $path=~ s[$LIBD_RE][];
    $path=abs_path(glob($path));

    push @$Lib,$path;

  };

  return;

};

# ---   *   ---   *   ---
# overwrite

sub set_includes(@args) {
  clear_includes();
  push_includes(@args);

};

sub set_libs(@args) {
  clear_includes();
  push_includes(@args);

};

# ---   *   ---   *   ---
# shorthands

sub file($path) {
  return $Root.$path

};

sub dir($path=$NULLSTR) {
  return $Root.$path.q[/];

};

sub lib($name) {
  return $Root."lib/lib$name.a"

};

sub libdir($path=$NULLSTR) {
  return $Root."lib/$path/";

};

sub so($name) {
  return $Root."lib/lib$name.so"

};

sub cache($name) {
  return $Cache.$name

};

sub mem($name) {
  return $Mem.$name

};

sub trash($name) {
  return $Trash.$name;

};


# ---   *   ---   *   ---
# tells you which module within $Root a
# given file belongs to

sub modof($file) {
  return based(shpath($file));

};

# ---   *   ---   *   ---
# shortens pathname for sanity

sub shpath($path) {
  $path=~ s[$Root_Re][];
  return $path;

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
#in: two filepaths to compare
# Older Than; return a is older than b

sub ot($a,$b) {
  return !( (-M $a) < (-M $b) );

};

# ---   *   ---   *   ---
# "missing or older"
# file not found or file needs update

sub moo($a,$b) {
  return !(-e $a) || ot($a,$b);

};

# ---   *   ---   *   ---
# build exclusion re

sub exclude_paths($dashx) {

  $dashx=join q{|},@{$dashx};
  if(length $dashx) {$dashx.=q{|}};

  $dashx.=q{
    nytprof | data | docs | tests | legacy

  | __pycache__

  };

  return qr{(?:$dashx)}x;

};

# ---   *   ---   *   ---
# inspects a directory within root

sub walk($path,%O) {

  # defaults
  $O{-r}//=0;
  $O{-x}//=[];

  # filetree obj
  my $frame     = Tree::File->get_frame();
  my $root_node = undef;

  # sanitize input
  $path         = dir($path) if !(-d $path);
  $O{-x}        = exclude_paths($O{-x});

  # what we care about
  my @pending   = ($path,undef);
  my $out       = undef;

  my $excluded  = qr{$DOT_BEG|$O{-x}};

# ---   *   ---   *   ---
# prepend and open

  while(@pending) {

    $path      = shift @pending;
    $root_node = shift @pending;

    # nit root on first run
    my $dst=(!defined $root_node)
      ? $frame->nit($root_node,$path)
      : $root_node
      ;

    # default out to root
    $out//=$dst;

    # make tree from file list
    for my $f(dorc($path,$excluded)) {

      if(-f "$path/$f") {
        $frame->nit($dst,$f);

      } elsif(($O{-r}) && (-d "$path$f/")) {

        unshift @pending,

          "$path$f/",
          $frame->nit($dst,"$f/")

        ;

      };

    };

  };

  return $out;

};


# ---   *   ---   *   ---
# gives object file path from source file path

sub obj_from_src($src,%O) {

  # default
  $O{use_trash}//=1;
  $O{ext}//=q[.o];

  my $out=$src;

  if($O{use_trash}) {
    $out=~ s[$Root_Re][$Trash];

  };

  if(defined $O{ext}) {
    $out=~ s[$ANYEXT_RE][$O{ext}];

  };

  return $out;

};

# ---   *   ---   *   ---
1; # ret
