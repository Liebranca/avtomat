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
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Path;
  use v5.42.0;
  use strict;
  use warnings;

  use File::Copy qw(copy);
  use Cwd qw(abs_path getcwd);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_dir);

  use Arstd::String qw(cat catpath);
  use Arstd::Path qw(based reqdir relto extwap);
  use Arstd::Array qw(filter);
  use Arstd::Bin qw(dorc moo ot);
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  our @ISA=qw(Exporter);
  our @EXPORT_OK=qw(
    root
    set_root
    swap_root
    relto_root

    include

    modof
    cachep
    filep
    dirp
    trashp
    ctrashp
    memp
    configp
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.6a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub libd_re {return qr{^\s*\-L}};
sub libf_re {return qr{^\s*\-l}};
sub inc_re {return qr{^\s*\-I}};

sub subpath_list {
  return qw(cache trash config mem);
};


# ---   *   ---   *   ---
# these are all wraps to the same F;
# so we build the subroutines from a template
#
# [0]: byte ptr ; new value | null#
# [*]: global state

sub import {
  # avoid running method generation more than once
  state $nit=0;
  my @out=__PACKAGE__->export_to_level(1,@_);

  return @out if $nit;

  # generate methods...
  no strict 'refs';
  for(root=>subpath_list()) {
    my $fnstr=join "\n",(
      # this is the F in question
      #
      # it just sets if a value is passed,
      # then returns the static
      "sub {",
      "  state \$$ARG=null;",
      "  \$$ARG=\$_[0] if ! is_null(\$_[0]);",

      "  return \$$ARG;",
      '};',
    );

    # ^make subroutine from string,
    # ^then make new symbol
    my $fn=eval $fnstr;
    *{$ARG}=$fn;
  };

  # set default value for root
  set_root($ENV{'ARPATH'});
  $nit |= 1;

  use strict 'refs';
  return @out;
};


# ---   *   ---   *   ---
# just lists of inc/lib paths
#
# [0]: byte pptr ; values to push | null
# [*]: global state

sub include {
  state $inc=[];

  if(int @_) {
    pathlist_prepush($inc,qr{^\s*\-I},@_);
    push @$inc,@_;
  };

  return $inc;
};

sub lib {
  state $lib=[];

  if(int @_) {
    pathlist_prepush($lib,qr{^\s*\-L}i,@_);
    push @$lib,@_;
  };

  return $lib;
};


# ---   *   ---   *   ---
# ^~~
#
# [0]: mem  ptr  ; dst array
# [1]: re        ; pattern
# [2]: byte pptr ; values

sub pathlist_prepush {
  my ($dst,$re)=(shift,shift);
  for(@_) {
    $ARG=~ s[$re][];
    $ARG=abs_path(glob($ARG));
  };

  return;
};


# ---   *   ---   *   ---
# sets topdir and subpaths from it
#
# [0]: byte ptr ; root dir
# [!]: overwrites lib and include path lists

sub set_root {
  include_cl();
  lib_cl();

  my $root=root(abs_path($_[0]));
  for(subpath_list()) {
    my $path=catpath($root,".$ARG");

    # set state and ensure directory exists
    eval("$ARG('$path')");
    reqdir($path);
  };

  include($root,catpath($root,'include'));
  lib(catpath($root,'lib'));

  return;
};


# ---   *   ---   *   ---
# used when you're only setting root
# for a quick operation and need to
# get back to the previous context after it

sub swap_root {
  state $back=[];

  # early exit if no swap needed
  return root() if (
     ($_[0] && $_[0] eq root())
  || (is_null($_[0]) &&! int @$back)
  );

  # swap to previous?
  if(is_null($_[0])) {
    my $path=pop @$back;
    my (
      $root,
      $inc,
      $lib,
      $cache,
      $trash,
      $config,
      $mem,
    )=@$path;

    set_root($root);
    include_cl();
    lib_cl();
    include(@$inc);
    lib(@$lib);
    cache($cache);
    trash($trash);
    config($config);
    mem($mem);

  # ^save current, *then* swap to new
  } else {
    push @$back,[
      root(),
      include(),
      lib(),
      cache(),
      trash(),
      config(),
      mem(),
    ];

    set_root($_[0]);
  };

  return root();
};


# ---   *   ---   *   ---
# to quickly detect root in path...

sub root_re {
  my $s=cat('^(?:\./?|',root(),')',);
  return qr{$s};
};


# ---   *   ---   *   ---
# set/get current module
#
# [0]: byte ptr ; name of module
# [*]: global state

sub module {
  state $mod=null;

  # value passed?
  if(! is_null($_[0])) {
    # catch invalid
    my $path=catpath(root(),$_[0]);

    throw "Invalid module path '$path'"
    if ! is_dir($path);

    # all OK, set state
    $mod=$_[0];
  };

  return $mod;
};


# ---   *   ---   *   ---
# SEARCH PATH SETTERS

# ---   *   ---   *   ---
# wipe out

sub include_cl {
  my $have=include();
  @$have=();

  return;
};

sub lib_cl {
  my $have=lib();
  @$have=();

  return;
};


# ---   *   ---   *   ---
# tells you which module within root a
# given file belongs to
#
# [0]: byte ptr ; file
# [<]: byte ptr ; module name (new string)

sub modof {
  relto_root($_[0]);
  return based($_[0]);
};


# ---   *   ---   *   ---
# makes path relative to current root
#
# [0]: byte ptr ; path
# [<]: string is not null
#
# [!]: overwrites input string

sub relto_root {
  return relto($_[0],root());
};


# ---   *   ---   *   ---
# batch-copy missing/updated
# for $O eq (dst => src)
#
# [0]: byte pptr ; [src => dst] array
# [*]: copies files

sub cpmac {
  # catch invalid input
  throw "Uneven elements in filename array; "
  .     "need [src => dst] for cpmac"

  if int(@_) & 1;

  # batch copy
  for(my $i=0;$i < int(@_);$i+=2) {
    my ($src,$dst)=($_[$i+0],$_[$i+1]);
    copy($src,$dst) if moo($dst,$src);
  };

  return;
};


# ---   *   ---   *   ---
# gives file of same name but on a
# different folder and/or different extension
#
# [0]: byte ptr ; source path
# [<]: byte ptr ; object path (new string)

sub fmirror {
  my $out = shift;
  my %O   = @_;

  # set defaults
  $O{reloc} //= [root_re() => trash()];
  $O{ext}   //= 'o';

  # swap folder?
  if($O{reloc} ne 0) {
    my ($re,$loc)=(@{$O{reloc}});
    $out=~ s[$re][];
    $out=  catpath($loc,$out);
  };

  # swap extension?
  extwap($out,$O{ext})
  if ! is_null($O{ext});

  relto_root($out);
  return $out;
};


# ---   *   ---   *   ---
# ^lises

sub src_from_obj {
  my $out = shift;
  my %O   = @_;

  # set defaults
  $O{ext}   //= null;
  $O{reloc} //= [qr{\.trash/} => null()];

  # give copy
  return fmirror($out,%O);
};

sub obj_from_src {
  my $out = shift;
  my %O   = @_;

  $O{ext}   //= 'o';
  $O{reloc} //= [root_re() => trash()];

  return fmirror($out,%O);
};


# ---   *   ---   *   ---
# removes files from directory
#
# [0]: byte ptr  ; path to dir
# [1]: byte pptr ; [option => value] array
#
# [*]: does not recurse by default

sub cl_dir {
  my $path = shift;
  my %O    = @_;

  my @have=xdorc($path,%O,-f=>1);

  filter(\@have);
  unlink($ARG) for @have;

  return;
};


# ---   *   ---   *   ---
# shorthands

sub filep   {return catpath(root(),@_)};
sub dirp    {return catpath(root(),@_,null)};
sub cachep  {return catpath(cache(),@_)};
sub configp {return catpath(config(),@_)};
sub memp    {return catpath(mem(),@_)};
sub trashp  {return catpath(trash(),@_)};
sub ctrashp {return trashp(module())};
sub libdirp {return catpath(lib()->[0],@_)};

sub static_libp {
  my $name=pop;
  return catpath(libdirp(@_),"lib${name}.a");
};

sub shared_libp {
  my $name=pop;
  return catpath(libdirp(@_),"lib${name}.so");
};

sub shwlp {
  my $name=pop;
  return catpath(libdirp(@_),".$name");
};


# ---   *   ---   *   ---
1; # ret
