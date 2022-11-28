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

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::String;
  use Arstd::Array;
  use Arstd::Hash;
  use Arstd::Path;
  use Arstd::IO;

  use Tree::File;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---

our $Cur_Module=$NULLSTR;

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
# these are just for readability
# we could add checks though...

sub config_file($path) {return $Config.$path};

sub config_dir($path) {
  return $Config.$path.q[/];

};

# ---   *   ---   *   ---
# shortcuts for making paths to main lib dir

sub lib($name=$NULLSTR) {return $Root."lib/$name"};
sub so($name) {return $Root."lib/lib$name.so"};

# ^idem, .cache dir
sub cache_file($name) {return $Cache.$name};
sub mem_file($name) {return $Mem.$name};

# ---   *   ---   *   ---
# gives object file path from source file path

sub obj_from_src($src,%O) {

  # default
  $O{use_trash}//=1;
  $O{depfile}//=0;

  my $ext=($O{depfile})
    ? q[\.d]
    : q[\.o]
    ;

  my $out=$src;

  if($O{use_trash}) {
    $out=~ s/$Root_Re/$Trash/;

  };

  $out=~ s/\.[\w|\d]*$/$ext/;

  return $out;

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
  return based(shpath($file));

};

# ---   *   ---   *   ---
# shortens pathname for sanity

sub shpath($path) {
  $path=~ s[$Root_Re][];
  return $path;

};

# ---   *   ---   *   ---
# takes out the trash!

sub clear_dir($path,%O) {

  my $tree  = walk($path,%O);
  my @files = $tree->get_file_list(
    full_path=>1

  );

  array_filter(\@files);

  for my $f(@files) {
    unlink $f;

  };

};

# ---   *   ---   *   ---
# ^recursively for module trashcan

sub empty_trash($name) {
  clear_dir("$Trash$name/",-r=>1);

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
# get symbol typedata from shadow lib

sub symrd($mod) {

  my $src=lib(".$mod");

  my $out={};

  # existence check
  if(!(-e $src)) {
    print "Can't find shadow lib '$mod'\n";
    goto TAIL;

  };

  $out=retrieve($src) or croak strerr($src);

# ---   *   ---   *   ---

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# rebuilds shared objects if need be

sub soregen($soname,$libs_ref,$no_regen=0) {

  my $sopath=so($soname);
  my $so_gen=!(-e $sopath);

  my @libs=@{$libs_ref};
  my %symtab=(

    deps=>[],
    objects=>{}

  );

# ---   *   ---   *   ---
# recover symbol table

  my @o_files=();
  for my $lib(@libs) {
    my $f=symrd($lib);

    # so regen check
    if(!$so_gen) {
      $so_gen=ot($sopath,ffind('-l'.$lib));

    };

    # append
    for my $o(keys %{$f->{objects}}) {
      my $obj=$f->{objects}->{$o};
      $symtab{objects}->{$Root.$o}=$obj;

    };

    push @{$symtab{deps}},$f->{deps};

  };

# ---   *   ---   *   ---
# generate so

  if($so_gen && !$no_regen) {

    # recursively get dependencies
    my $o_libs='-l'.( join ' -l',@libs );

    my $deps=join q{ },@{$symtab{deps}};

    my $libs=libexpand($o_libs);
    my $objs=join q{ },keys %{$symtab{objects}};

    olink(

      $objs,
      $sopath,

      deps=>$deps,
      libs=>$libs,

      shared=>1,

    );

  };

  return \%symtab;

};

# ---   *   ---   *   ---

sub sofetch($symtab) {

  my $tab={};

  for my $o(keys %{$symtab->{objects}}) {

    my $obj=$symtab->{objects}->{$o};
    my $funcs=$obj->{functions};

    my $ref=$tab->{$o}=[];

    for my $fn_name(keys %$funcs) {

      my $fn=$funcs->{$fn_name};
      my $rtype=$fn->{type};

      push @$ref,[$fn_name,$rtype,@{$fn->{args}}];

    };

  };

  return $tab;

};

# ---   *   ---   *   ---
1; # ret
