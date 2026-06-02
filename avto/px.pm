#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO PX
# project handler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::px;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Cwd qw(abs_path getcwd);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);

  use Arstd::String qw(catpath);
  use Arstd::Path qw(reqdir extwap extof);

  use Tree::File;
  use Shb7::Path qw(
    root
    module
    swap_root
    relto_root
    relto_mod
    dirp
    trashp
    cachep
    memp
    modp
    configp
  );

  use lib "$ENV{ARPATH}/lib/";
  use AR;
  use avto::cfg;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# make/load/clean project struc

sub new {
  my ($class,$src)=@_;
  my $px=bless avto::cfg->new($src),$class;

  # jump to root dir
  $px->setcur();

  # ensure we have these standard paths
  reqdir($ARG) for (
    dirp("bin"),
    dirp("lib"),
    dirp("include"),
    trashp(),
    cachep(),
    memp(),
    configp(),
  );

  # scan project for files,
  # then setup the build directory
  $px->make_file_tree();
  $px->make_build_dir();
  $px->make_file_list();

  return $px;
};


# ---   *   ---   *   ---
# fetch name of makefile

sub makefile {
  my ($px)=@_;
  return modp(".avto");
};


# ---   *   ---   *   ---
# moves to project root and sets
# this project as the active one

sub setcur {
  my ($px)=@_;

  $px->{back}=swap_root($px->{root});
  module($px->{name});

  return;
};


# ---   *   ---   *   ---
# make file tree for a project
#
# we use this to find files and
# run checksums

sub make_file_tree {
  my ($px,%O)=@_;

  my $dirpath=catpath($px->{root},$px->{name});
  $px->{tree}=Tree::File->new($dirpath);
  $px->{tree}->expand(-r=>1,-x=>$px->{skip});

  return;
};


# ---   *   ---   *   ---
# mirrors project structure
# into [root]/.trash/[mod]

sub make_build_dir {
  my ($px)=@_;

  # get trash dir
  my $path  = dirp($px->{name});
  my $trash = trashp($px->{name});
  $px->{trash}=$trash;

  # get project directory tree
  my $tree=Tree::File->new($path);
  $tree->expand(-r=>1,-x=>$px->{skip});

  # force dump to exist
  reqdir($trash);

  # walk dirs
  my $px_re=qr{$px->{name}/?$px->{name}/};
  for($tree->get_dir_list(inclusive=>1)) {
    # don't bother with top of the tree
    next if $ARG eq $ARG->root();

    my $subpath=$ARG->get_full();
    relto_root($subpath);

    my $tdir =  "$trash$subpath";
       $tdir =~ s[$px_re][$px->{name}/];

    # force dump to exist
    reqdir($tdir);
  };
  return;
};


# ---   *   ---   *   ---
# sorts files into cathegories,
# each corresponding to some build F

sub make_file_list {
  my ($px)=@_;
  my @dir=$px->{tree}->get_dir_list(
    full=>0,
    inclusive=>1
  );

  # a table of files for which compilation
  # needs to be skipped
  #
  # we only need it here so we make it
  # and then delete it
  my $tab=$px->{fskiptab}={};
  for(qw(xcpy lcpy)) {
    my $ar=$px->{$ARG};
    %$tab=(%$tab,map {$ARG=>1} @$ar);
  };

  # get file list for compilation
  $px->{to_build} //= [];
  $px->filesort($ARG) for @dir;

  # ^map file list to compiler wrappers
  for(qw(flat CMAM MAM)) {
    my $pkg="avto\::bk\::$ARG";
    AR::load($pkg);

    $px->{$ARG}=$pkg->new($px);
  };

  # cleanup and give
  delete $px->{to_build};
  delete $px->{fskiptab};

  return;
};


# ---   *   ---   *   ---
# sorts contents of file tree directory

sub filesort {
  my ($px,$node)=@_;
  my @file=$node->get_filepath_list(
    full=>1,
    max_depth=>1,
  );

  # shorten paths
  # pop mod from start
  for(@file) {
    next if exists $px->{fskiptab}->{$ARG};
    push @{$px->{to_build}},$ARG;
  };
  return;
};


# ---   *   ---   *   ---
# removes files that match re from temp array,
# then gives back the removed files

sub filepop {
  my ($px,$re)=@_;

  # get all files matching re
  my @have = @{$px->{to_build}};
  my @out  = grep {$ARG=~ $re} @{$px->{to_build}};

  # ^keep only files that don't
  @{$px->{to_build}}=grep {! ($ARG=~ $re)} @have;

  return @out;
};


# ---   *   ---   *   ---
1; # ret
