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
  use Chk qw(is_null is_arrayref is_dir is_file);

  use Arstd::String qw(cat catpath);
  use Arstd::Path qw(based reqdir relto extwap);
  use Arstd::Array qw(filter dupop nroll);
  use Arstd::Bin qw(dorc moo ot);
  use Arstd::rd;
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  our @ISA=qw(Exporter);
  our @EXPORT_OK=qw(
    root
    module
    set_root
    swap_root
    relto_root
    relto_mod

    include
    from_config

    modof
    cachep
    filep
    dirp
    shared_libp
    static_libp
    libdirp
    trashp
    ctrashp
    modp
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
# [0]: byte ptr ; new value | null
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
  set_root($ENV{ARPATH});
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
    pathlist_push($inc,qr{^\s*\-I},@_);
    dupop($inc);
  };

  return $inc;
};

sub lib {
  state $lib=[];

  if(int @_) {
    pathlist_push($lib,qr{^\s*\-L},@_);
    dupop($lib);
  };

  return $lib;
};


# ---   *   ---   *   ---
# ^cleanup before pushing
#
# [0]: mem  ptr  ; dst array
# [1]: re        ; pattern
# [2]: byte pptr ; values

sub pathlist_push {
  my ($dst,$re)=(shift,shift);
  for(@_) {
    $ARG=~ s[$re][];
    $ARG=abs_path(glob($ARG));
  };
  push @$dst,@_;
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
  my ($have)=@_;

  # set new root only if needed
  if(! is_arrayref($have)) {
    my $out=to_array();
    set_root($have) if $have ne root();

    return $out;
  };

  # ^else restore old (also *only* if needed)
  return from_array($have);
};


# ---   *   ---   *   ---
# get current path setup

sub to_array {
  return [
    root(),
    include(),
    lib(),
    cache(),
    trash(),
    config(),
    mem(),
  ];
};


# ---   *   ---   *   ---
# ^restore

sub from_array {
  my ($have)=@_;
  return to_array() if $have->[0] eq root();

  my (
    $root,
    $inc,
    $lib,
    $cache,
    $trash,
    $config,
    $mem,

  )=@$have;

  set_root($root);
  include_cl();
  lib_cl();
  include(@$inc);
  lib(@$lib);
  cache($cache);
  trash($trash);
  config($config);
  mem($mem);

  return to_array();
};


# ---   *   ---   *   ---
# to quickly detect root in path...

sub root_re {
  my $s='\./|' . root();
  return qr{^(?:$s)};
};

sub module_re {
  my $mod = module();
  my $s   = "\./$mod|" . catpath(root(),$mod);

  return qr{^(?:$s)};
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

sub relto_mod {
  return relto($_[0],catpath(root(),module()));
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
  $O{rel}   //= 1;

  # swap folder?
  if($O{reloc} ne 0) {
    my ($re,$loc)=(@{$O{reloc}});
    $out=~ s[$re][];
    $out=  catpath($loc,$out);
  };

  # swap extension?
  extwap($out,$O{ext})
  if ! is_null($O{ext});

  relto_root($out) if $O{rel};
  return $out;
};


# ---   *   ---   *   ---
# ^lises

sub src_from_obj {
  my $out = shift;
  my %O   = @_;

  # set defaults
  $O{ext}   //= null;
  $O{rel}   //= 1;
  $O{reloc} //= [qr{\.trash/} => null()];

  # give copy
  return fmirror($out,%O);
};

sub obj_from_src {
  my $out = shift;
  my %O   = @_;

  $O{ext}   //= 'o';
  $O{rel}   //= 1;
  $O{reloc} //= [root_re() => trash()];

  return fmirror($out,%O);
};


# ---   *   ---   *   ---
# fetches config file, falling back
# to a list of alternatives if
# no file is found

sub from_config {
  my ($fname,%O)=@_;
  $O{roll} //= 0;
  $O{root} //= [];

  dupop($O{root});

  # look for files and combine if needed,
  # else give first found
  my @out=();
  for(@{$O{root}}) {
    nroll(\@out,[from_config_rd($ARG,$fname)]);
    last if @out &&! $O{roll};
  };
  return @out;
};

sub from_config_rd {
  my ($root,$fname)=@_;
  my $back = swap_root($root);
  my $src  = configp($fname);
  my @out  = (is_file($src)) ? rd($src) : () ;

  swap_root($back);
  return @out;
};


# ---   *   ---   *   ---
# shorthands

sub filep   {return catpath(root(),@_)};
sub dirp    {return catpath(root(),@_,null)};
sub cachep  {return catpath(cache(),@_)};
sub configp {return catpath(config(),@_)};
sub modp    {return catpath(root(),module(),@_)};
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
