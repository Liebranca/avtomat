#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7 FIND
# Searches set paths for
# dirs and files and libs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Find;

  use v5.36.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path getcwd);
  use English qw(-no_match_vars);

  use Carp;
  use Readonly;
  use Storable;

  use Exporter 'import';

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::String;
  use Arstd::Array;
  use Arstd::Hash;
  use Arstd::IO;

  use Shb7::Path;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# adds to your namespace

  our @EXPORT=qw(

    ffind
    wfind

    libexpand

  );

# ---   *   ---   *   ---
# sets search path and filelist accto filename

sub illnames($fname,@exts) {

  my @files=();
  my $search_in;

  # from [ext0 ext1] to [.ext0 .ext1]
  map {$ARG=".$ARG"} @exts;
  push @exts,$NULLSTR;

  # libsearch
  if($fname=~ s[$Shb7::Path::LIBF_RE][]) {

    push @files,
      "lib$fname.so",
      "lib$fname.a"

    ;

    $search_in=$Shb7::Path::Lib;
    push @files,$fname;

  # common file search
  } else {
    $search_in=$Shb7::Path::Include;

    push @files,
      (map {$fname.$ARG} @exts),
      $fname

    ;

  };

  return ($search_in,@files);

};

# ---   *   ---   *   ---
# ffind errme

sub throw_no_file($fname,@exts) {

  my $ext_list=$NULLSTR;
  pop @exts if @exts>1;

  $ext_list=join q[,],@exts;
  if(length $ext_list) {
    $ext_list="(exts==$ext_list)";

  };

  errout(
    q[Could not find file '%s' in path %s],

    args=>[$fname,$ext_list],
    lvl=>$AR_ERROR,

  );

};

# ---   *   ---   *   ---
# iters search path
# stops if name found

sub fsearch($search_in,@files) {

  my $out=undef;

  for my $path(

    @$search_in,
    $Shb7::Path::Root

  ) {

    map {
      $out="$path/$ARG"
      if -f "$path/$ARG"

    } @files;

    last if defined $out;

  };

  return $out;

};

# ---   *   ---   *   ---
# find file within search path

sub ffind($fname,@exts) {

  if(-f $fname) {
    return abs_path($fname);

  };

  # get search directory and
  # filename variations
  my ($search_in,@files)=illnames(
    $fname,@exts

  );

  # perform search and errchk
  my $src=fsearch($search_in,@files);
  if(!defined $src) {
    throw_no_file($fname,@exts);

  };

  return $src;

};

# ---   *   ---   *   ---
# find files matching pattern

sub wsearch($search_in,$re) {

  my @out=();

  # iter search path
  for my $path(@$search_in) {

    my $tree=Shb7::Path::walk($path,-r=>1);

    for my $dir($tree->get_dir_list(
      full_path=>0,
      keep_root=>1,

    )) {

      my @files=$dir->get_file_list(
        full_path=>1,
        max_depth=>1,

      );

      push @out,grep m[$re],@files;

    };

  };

  return @out;

};

# ---   *   ---   *   ---
# wildcard search

sub wfind($pattern) {

  my ($search_in,@patterns)=illnames($pattern);

  # escape non-wildcard bits
  for my $pat(@patterns) {

    my @bits=
      map {"\Q$ARG"}
      split $Shb7::Path::WILDCARD_RE,$pat

    ;

    $pat=join q{[\\s\\S]+},@bits;

  };

  # OR the patterns into a single regex
  my $re=join q[|],@patterns;
  $re=qr{$re}x;

  # give grep'd search path
  return wsearch($search_in,$re);

};

# ---   *   ---   *   ---
# get .lib files from path and names

sub get_dotlibs($search_in,@names) {

  my @out=();

  for my $path(@$search_in) {
    push @out,grep {-f $ARG} (
      map {"$path/.$ARG"} @names

    );

  };

  return @out;

};

# ---   *   ---   *   ---
# get deps from .libs

sub get_dotlib_deps($path) {

  my $f=retrieve($path)
  or croak strerr($path);

  my @deps=(defined $f->{deps})
    ? @{$f->{deps}}
    : ()
    ;

  return @deps;

};

# ---   *   ---   *   ---
# lib dependency search

sub ldsearch($search_in,@names) {

  my @out=();

  for my $path(get_dotlibs(

    $search_in,
    @names

  )) {

    push @out,get_dotlib_deps($path);

  };

  array_filter(\@out);
  array_dupop(\@out);

  return @out;

};

# ---   *   ---   *   ---
# true if $name is -L[path]
#
# if true, appends to current
# search if not present

sub is_libpath($search_in,$name) {

  my $out=0;

  if(begswith($name,q[-L])) {

    my $s     = substr $name,2,length $name;
    my $match = lfind($search_in,[$s]);

    if(!@$match) {
      push @$search_in,$s;

    };

    $out=1;

  };

  return $out;

};

# ---   *   ---   *   ---
# get lib search path from -L[name]
# and lib names from -l[name]

sub dashl($search_in,@libs) {

  my @out=();

  for my $lib(@libs) {
    next if is_libpath($search_in,$lib);
    push @out,(substr $lib,2,length $lib);

  };

  array_filter(\@out);
  return @out;

};

# ---   *   ---   *   ---
# recursively appends lib dependencies to LIBS var

sub libexpand($libs) {

  my $search_in = $Shb7::Path::Lib;

  my @found     = (@$libs);
  my @deps      = ();

# ---   *   ---   *   ---

  while(@found) {

    my @names=dashl($search_in,@found);

    @found=ldsearch(
      $search_in,
      @names

    );

    push @deps,@found;

  };

  push @$libs,@deps;

  array_dupop($libs);
  array_filter($libs);

};

# ---   *   ---   *   ---

sub build_meta($path) {

  my $M=retrieve($path.'/.avto-cache');

  my $out={

    incl => $M->{incl},
    libs => $M->{libs},

  };

  my $old=getcwd();
  chdir $Shb7::Path::Root;

  libexpand($out->{libs});

  for my $dir(@{$out->{incl}}) {
    $dir=~ s[$Shb7::Path::INCL_RE][];
    $dir=abs_path($dir);

    $dir=q[-I].$dir;

  };

  chdir $old;
  return $out;

};


# ---   *   ---   *   ---
1; # ret
