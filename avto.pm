#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO
# build my builds
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto;
  use v5.42.0;
  use strict;
  use warnings;

  use Storable qw(retrieve freeze thaw);
  use Cwd qw(getcwd abs_path);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file is_dir);

  use Arstd::String qw(catpath);
  use Arstd::Array qw(dupop);
  use Arstd::Bin qw(perl moo nuke deepcpy);
  use Arstd::Path qw(basef dirof parof);
  use Arstd::throw;

  use Cli;
  use Vault;
  use Shb7;
  use Log;

  use lib "$ENV{ARPATH}/lib/";
  use Shb7::Path qw(swap_root);
  use Shb7::Find qw(ffind);
  use avto::cfg;
  use avto::px;
  use avto::switch;
  use avto::emit;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub fext {return 'px'};


# ---   *   ---   *   ---
# entry point

sub import {
  my ($class,@opt)=@_;

  # read commandline
  my ($cli,$dirpath)=$class->cli(@opt);

  # shorten names
  my $cfg  = "$dirpath/avto.cfg";
  my $ckey = Vault->mykey(cache_key($cfg));

  # make sure avto.cfg exists in this directory
  throw "avto: no *.cfg file found at '$dirpath'"
  if!   is_file($cfg);


  # trigger full recompilation?
  my $name=basef($dirpath);
  Log->mupdate($name);
  if($cli->{clean}) {
    my $trash=catpath(
      parof($dirpath),
      '.trash',
      $name,
    );
    nuke($trash,-r=>1,-d=>1);
  };
  # get project and set as current
  Log->step('reading project cache');
  my $px=pxfet($cli,$cfg,$ckey);
  $px->setcur();

  # ^ update the project cache,
  #   and *then* apply CLI overrides
  cksum($px);
  apply_cli($px,$cli);
  load_presets($px);

  # expand search paths from dependencies,
  # and then *set* the final search path
  libex($px);
  Shb7::Path::include(@{$px->{inc}});
  Shb7::Path::lib(@{$px->{lib}->{dir}});

  # get switches for gcc...
  my $sw=avto::switch::proc($px);
  $sw->{clean} //= $cli->{clean};

  # generate makescript if it's not there
  my $make=$px->makefile();
  avto::emit::run($px) if moo($make,$ckey);

  # serialize the switches and project struc,
  # then pass them to the generated script
  my @argv=(
    freeze($px),
    freeze($sw)
  );
  perl($px->makefile(),@argv);

  # ^if all went well, restore and give
  Log->step('done');
  swap_root($px->{back});

  return;
};


# ---   *   ---   *   ---
# get project struc
#
# triggers update if either
# forced to or found to be necessary

sub pxfet {
  my ($cli,$cfg,$ckey)=@_;

  # this is used to regenerate the project,
  # by re-reading the config file
  my $regen=sub {return avto::px->new($cfg)};

  # ^ note that regenerating the project isn't
  #   really that costly, but we still prefer
  #   using the cached version whenever possible
  return (! $cli->{update} &&! moo($ckey,$cfg))
    ? Vault->cached(cache_key($cfg),$regen)
    : $regen->()
    ;
};


# ---   *   ---   *   ---
# checksum project tree
# a __copy__ of the project struc
# will be saved if there's changes
#
# NOTE that we use a COPY of the struc
#      to avoid CLI overrides being
#      saved to the cache!

sub cksum {
  my ($px)=@_;
  my @diff=$px->{tree}->get_cksum_diff();

  Vault->schedup(
    cache_key($px),
    deepcpy($px)

  ) if @diff;

  return;
};


# ---   *   ---   *   ---
# ^get key for *.px file

sub cache_key {
  my ($src)=@_;
  return (ref $src)
    ? $src->{name}
    : basef(dirof($src))
    ;
};


# ---   *   ---   *   ---
# get user-defined presets from
# config files

sub load_presets {
  my ($px)=@_;
  $px->{preset}={};

  # get sum of local and global config,
  # then keep only preset definitions
  my $data = {avto::cfg::load($px,roll=>1,rev=>1)};
  my @key  = keys %$data;
  my $re   = qr{\-preset$};
  for(@key) {
    # ignore other settings
    next if! ($ARG=~ $re);

    # remove suffix and save
    my $cpy=$ARG;
    $cpy=~ s[$re][];

    $px->{preset}->{$cpy}=$data->{$ARG};
  };
  # force defaults
  $px->{preset}->{obc}  //= [];
  $px->{preset}->{link} //= [];
  $px->{preset}->{arch} //= [];

  return;
};


# ---   *   ---   *   ---
# recursive lib expansion

sub libex {
  my ($px)=@_;

  # setup initial search path
  my $dst=$px->{lib};
  my $tmp=[@{Shb7::Path::include()}];

  Shb7::Path::include(@{$dst->{dir}});

  # look for a shwl for each lib->file
  for(@{$px->{lib}->{file}}) {
    my $shwl=avto::shwl::find($ARG);
    next if! is_null($shwl);

    # if shwl is found, open and load
    # additional includes and libs
    push @{$px->{inc}},$shwl->{inc};
    push @{$dst->{dir}},@{$shwl->{lib}->{dir}};
    push @{$dst->{file}},@{$shwl->{lib}->{file}};
  };

  # restore search path
  Shb7::Path::include_cl();
  Shb7::Path::include(@$tmp);

  # cleanup and give
  dupop($dst->{dir});
  dupop($dst->{file});

  return;
};


# ---   *   ---   *   ---
# command line interface

sub cli {
  my ($class,@opt)=@_;

  # read args
  my $cli=Cli->new(cli_opt());
  my ($dirpath)=$cli->take(@opt);

  # default to current dir
  $dirpath=getcwd() if is_null($dirpath);

  # expand dirpath and validate
  ($dirpath)=abs_path(glob($dirpath));
  throw "avto: target '$dirpath' is a file -- "
  .     "a directory is required"

  if    is_file($dirpath);

  throw "avto: target '$dirpath' is not a "
  .     "valid directory"

  if!   is_dir($dirpath);

  return ($cli,$dirpath);
};


# ---   *   ---   *   ---
# override project *.cfg keys
# from commandline args

sub apply_cli {
  my ($px,$cli)=@_;

  # force *.so building
  if($cli->{shared}) {
    $px->{bld}->{mode}='so';
  };

  # these are copied as-is
  for(qw(debug strip entry output)) {
    next if! $cli->{$ARG};
    $px->{$ARG}=$cli->{$ARG};
  };
  for(qw(link obc arch)) {
    next if! @{$cli->{$ARG}};
    $px->{bld}->{$ARG}=$cli->{$ARG};
  };

  # these we can just straight cat
  push @{$px->{def}},@{$cli->{def}};
  push @{$px->{inc}},@{$cli->{inc}};
  push @{$px->{lib}->{dir}},@{$cli->{libdir}};
  push @{$px->{lib}->{file}},@{$cli->{libfile}};

  return;
};


# ---   *   ---   *   ---
# ROM
#
# placed at the end because the
# list is pretty long and we're
# not using it much on this file

sub cli_opt {return (
  # avtomat specific options
  {
    id    => 'update',
    short => '-u',
    long  => '--update',
    argc  => 0

  },{
    id    => 'clean',
    short => '-c',
    long  => '--clean',
    argc  => 0

  },{
    id    => 'debug',
    short => '-g',
    long  => '--debug',
    argc  => 0

  },{
    id    => 'clean-debug',
    short => '-gc',
    long  => '--clean-debug',
    argc  => 0,
    combo => ['+clean','+debug'],

  },{
    id    => 'arch',
    short => null,
    long  => '--arch',
    argc  => 'array'

  },{
    id    => 'obc',
    short => null,
    long  => '--obc',
    argc  => 'array'

  },{
    id    => 'link',
    short => null,
    long  => '--link',
    argc  => 'array'

  },


  # these are more or less the same as gcc
  {
    id      => 'def',
    short   => '-D',
    long    => null,
    argc    => 'array',

  },{
    id      => 'inc',
    short   => '-I',
    long    => null,
    argc    => 'array',

  },{
    id      => 'libdir',
    short   => '-L',
    long    => null,
    argc    => 'array',

  },{
    id      => 'libfile',
    short   => '-l',
    long    => null,
    argc    => 'array',

  },{
    id      => 'output',
    short   => '-o',
    long    => '--output',
    argc    => 1,

  },{
    id      => 'shared',
    short   => '-shared',
    long    => null,
    argc    => 0,

  },{
    id      => 'strip',
    short   => '-s',
    long    => '--strip',
    argc    => 0,

  },{
    id      => 'entry',
    short   => '-e',
    long    => '--entry',
    argc    => 1,

  },
)};


# ---   *   ---   *   ---
1; # ret
