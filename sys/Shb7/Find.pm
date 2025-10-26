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
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Find;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path getcwd);
  use English qw($ARG);

  use Storable qw(retrieve);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_file is_dir);

  use Arstd::String qw(has_prefix);
  use Arstd::Array qw(filter dupop);
  use Arstd::Hash qw(lfind);
  use Arstd::throw;

  use Tree::File;
  use Shb7::Path;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    ffind
    wfind
    libexpand
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# sets search path and filelist accto filename

sub illnames($fname,@exts) {
  my @files=();
  my $search_in;

  # libsearch
  my $re=qr{^\s*\-l};
  if($fname=~ s[$re][]) {
    push @files,(
      "lib$fname.so",
      "lib$fname.a"
    );

    $search_in=Shb7::Path::lib();
    push @files,$fname;

  # common file search
  } else {
    $search_in=Shb7::Path::include();

    push @files,map {"$fname.$ARG"} @exts;
    push @files,$fname;
  };

  return ($search_in,@files);
};


# ---   *   ---   *   ---
# iters search path
# stops if name found

sub fsearch($search_in,@files) {
  my $out=null;
  for my $path(@$search_in,Shb7::Path::root()) {
    for(@files) {
      ($out)=("$path/$ARG"),last
      if is_file("$path/$ARG");
    };

    last if ! is_null($out);
  };

  return $out;
};


# ---   *   ---   *   ---
# find file within search path

sub ffind($fname,@exts) {
  return abs_path($fname) if -f $fname;

  # get search directory and
  # filename variations
  my ($search_in,@files)=illnames($fname,@exts);

  # perform search and errchk
  my $out=fsearch($search_in,@files);

  throw "Could not find file '$fname' in PATH"
  if is_null($out);

  return $out;
};


# ---   *   ---   *   ---
# find files matching pattern

sub wsearch($search_in,$re) {
  my @out=();

  # iter search path
  for my $path(@$search_in) {
    # get filetree...
    my $tree=Tree::File->new($path);
    $tree->expand(-r=>1);

    # ^walk dirs in tree...
    for my $dir($tree->get_dir_list(
      full_path=>0,
      inclusive=>1,
    )) {
      # and check all files in dir
      my @files=$dir->get_filepath_list(
        full      => 1,
        max_depth => 1,
      );

      push @out,grep m[$re],@files;
    };
  };

  return @out;
};


# ---   *   ---   *   ---
# wildcard search

sub wildcard_re {qr{%}};
sub wfind($pattern) {
  my ($search_in,@patterns)=illnames($pattern);

  # escape non-wildcard bits
  $ARG=join(
    q{[\\s\\S]+},
    map {"\Q$ARG"} split(wildcard_re(),$ARG)

  ) for @patterns;

  # OR the patterns into a single regex
  my $re=join '|',@patterns;
  $re=qr{$re}x;

  # give grep'd search path
  return wsearch($search_in,$re);
};


# ---   *   ---   *   ---
# get .lib files from path and names

sub get_dotlibs($search_in,@names) {
  my @out=();

  for my $path(@$search_in) {
    push @out,grep {
      is_file($ARG)

    } map {
      "$path/.$ARG"

    } @names;
  };

  return @out;
};


# ---   *   ---   *   ---
# get deps from .libs

sub get_dotlib_deps($path) {
  my $f=retrieve($path)
  or throw "No SHWL in '$path'";

  my @deps=(defined $f->{dep})
    ? @{$f->{dep}}
    : ()
    ;

  return @deps;
};


# ---   *   ---   *   ---
# lib dependency search

sub ldsearch($search_in,@names) {
  my @out=();

  push @out,get_dotlib_deps($ARG)
  for get_dotlibs($search_in,@names);

  filter(\@out);
  dupop(\@out);

  return @out;
};


# ---   *   ---   *   ---
# true if $name is -L[path]
#
# if true, appends to current
# search if not present

sub is_libpath($search_in,$name) {
  my $out=0;

  if(has_prefix($name,'-L')) {
    my $s     = substr $name,2,length $name;
    my $match = lfind($search_in,[$s]);

    push @$search_in,$s if !@$match;
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

  filter(\@out);
  return @out;
};


# ---   *   ---   *   ---
# recursively appends lib dependencies to LIBS var

sub libexpand($libs) {
  my $search_in = Shb7::Path::lib();
  my @found     = (@$libs);
  my @deps      = ();

  while(@found) {
    my @names=dashl($search_in,@found);
    push @deps,ldsearch($search_in,@names);
  };

  push @$libs,@deps;
  dupop($libs);
  filter($libs);

  return;
};


# ---   *   ---   *   ---
# retrieve makescript cache
#
# [0]: byte ptr ; module dir
# [<]: mem  ptr ; Avt::Makescript object

sub build_meta {
  my $M   = retrieve("$_[0]/.avto-cache");
  my $out = {
    inc => $M->{inc},
    lib => $M->{lib},
  };

  my $old=getcwd();
  chdir Shb7::Path::root();

  libexpand($out->{lib});

  my $re=qr{^\s*\-I};
  for(@{$out->{inc}}) {
    $ARG=~ s[$re][];
    $ARG=abs_path($ARG);
    $ARG="-I$ARG";
  };

  chdir $old;
  return $out;
};


# ---   *   ---   *   ---
# find path to build folder
# from name of library

sub build_path($name) {
  my $path=Shb7::Path::dirp($name);
  if(! is_dir($path)) {
    my $libmeta=Shb7::Path::shwlp($name);
    $path=(is_file($libmeta))
      ? Shb7::Path::dirp(
          retrieve($libmeta)->{fswat}
        )

      : null
      ;
  };

  return $path;
};


# ---   *   ---   *   ---
1; # ret
