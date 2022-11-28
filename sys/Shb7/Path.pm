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

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::IO;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $F_SLASH_END;
  our $DOT_BEG;

  Readonly our $INCL_RE=>qr{^\s*\-I}x;
  Readonly our $LIBD_RE=>qr{^\s*\-L}x;
  Readonly our $LIBF_RE=>qr{^\s*\-l}x;

  Readonly our $WILDCARD_RE=>qr{\%};

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
# add to search path (include)

sub push_includes(@args) {

  for my $path(@args) {

    $path=~ s[$INCL_RE][];
    $path=abs_path(glob($path));

    push @$Include,$path;

  };

};

# ---   *   ---   *   ---
# add to search path (library)

sub push_libs(@args) {

  for my $path(@args) {

    $path=~ s[$LIBD_RE][];
    $path=abs_path(glob($path));

    push @$Lib,$path;

  };

  return;

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
# shorthands

sub file($path) {
  return $Root.$path

};

sub dir($path=$NULLSTR) {
  return $Root.$path.q[/];

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
1; # ret
