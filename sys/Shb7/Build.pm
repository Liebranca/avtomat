#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7 BUILD
# Bunch of gcc wrappers
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Build;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Storable qw(retrieve);

  use lib "$ENV{ARPATH}/lib/sys/";

  use Style qw(null);
  use Chk qw(
    is_null
    is_file
    is_dir
    is_arrayref
  );

  use Arstd::Array qw(dupop filter);
  use Arstd::Bin qw(ot);
  use Arstd::throw;

  use Shb7::Path;
  use Shb7::Find;

  use parent 'St';


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    push_makedeps
    clear_makedeps
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.9';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub DEFAULT {return {
  name    => 'out',
  entry   => '_start',

  lang    => 'fasm',
  file    => [],
  flag    => [],
  def     => [],
  inc     => [],
  lib     => [],
  libpath => [],

  shared  => 0,
  linking => 0,
  debug   => 0,
  clean   => 0,
  tgt     => 0,
}};


# ---   *   ---   *   ---
# GBL

sub makedeps {
  state $out={
    obj=>[],
    dep=>[],
  };
  return $out;
};


# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {
  # defaults
  $class->defnit(\%O);

  # condtionally add extra flags
  my $flag=[];

  unshift @$flag,q[-shared]
  if $O{shared};

  unshift @$flag,q[-g]
  if $O{debug};


  # make ice
  my $self=bless {
    name    => $O{name},
    file    => $O{file},
    entry   => $O{entry},

    def     => $O{def},
    inc     => $O{inc},
    lib     => [@{$O{libpath}},@{$O{lib}}],

    flag    => $flag,
    linking => $O{linking},
    tgt     => $O{tgt},

    clean   => $O{clean},
    lang    => $O{lang},

  },$class;

  # ^build meta and give
  $self->get_module_deps();
  $self->get_module_paths();

  return $self;
};


# ---   *   ---   *   ---
# adds to builder's file array

sub push_files($self,@data) {
  push @{$self->{file}},@data;
  return;
};


# ---   *   ---   *   ---
# adds to builder's flags array

sub push_flags($self,@data) {
  push @{$self->{flag}},@data;
  return;
};


# ---   *   ---   *   ---
# these are for generating mam's dependency lists
# in a nutshell: it's a hack

sub push_makedeps($obj,$dep) {
  my $have=makedeps();
  push @{$have->{obj}},$obj;
  push @{$have->{dep}},$dep;
  return;
};

sub clear_makedeps() {
  my $have=makedeps();
  %$have={obj=>[],dep=>[]};
  return;
};


# ---   *   ---   *   ---
# get dependencies for a module
# from build metadata

sub get_module_deps($self) {
  my @found=();
  my @paths=();

  filter($self->{lib});
  filter($self->{inc});

  while(@{$self->{lib}}) {
    # skip -L
    my $path=shift @{$self->{lib}};
    if($path=~ qr{^\s*\-L}) {
      push @paths,$path;
      next;
    };

    my $lib=$path;

    # remove -l and get path to module
    my $libf_re=qr{^\s*\-l};
    $path=~ s[$libf_re][];
    $path=Shb7::Find::build_path($path);

    # retrieve build data if present
    if(is_dir($path)) {
      my $meta=Shb7::Find::build_meta($path);

      push @{$self->{inc}},@{$meta->{inc}};
      push @found,$lib,@{$meta->{lib}};

    } else {
      push @found,$lib;
    };

  };

  push @{$self->{lib}},@paths;
  push @{$self->{lib}},@found;

  return;
};


# ---   *   ---   *   ---
# get current search paths

sub get_module_paths($self) {
  # convert paths to CLI args
  unshift @{$self->{lib}},"-L$ARG"
  for @{Shb7::Path::lib()};

  unshift @{$self->{inc}},"-I$ARG"
  for @{Shb7::Path::include()};

  # ^cleanup
  for($self->{inc},$self->{lib}) {
    filter($ARG,\&flgchk);
    dupop($ARG);
  };

  return;
};


# ---   *   ---   *   ---
# ^helper F to filter out invalid entries

sub flgchk {
  return defined($ARG) && 2 < length $ARG;
};


# ---   *   ---   *   ---
# return list of build files

sub list_obj($self) {
  return map {
    $ARG->{obj}

  } grep {
    ! defined $ARG->{__alt_out}

  } @{$self->{file}};
};

sub list_src($self) {
  return map {
    $ARG->{src}

  } @{$self->{file}};
};

sub list_dep($self) {
  return map {
    $ARG->{dep}

  } @{$self->{file}};
};


# ---   *   ---   *   ---
# gives stirr -L(path) -l(files) ...

sub libline($self) {
  return join ' ',@{$self->{lib}};
};


# ---   *   ---   *   ---
# symrd errme

sub throw_no_shwl($name,$path) {
  throw "Can't find SHWL for '$name' <$path>";
};


# ---   *   ---   *   ---
# get symbol typedata from shadow lib

sub symrd($mod) {
  my $out={};
  my $src=libdir() . ".$mod";

  # existence check
  throw_no_shwl($mod,$src) if ! is_file($src);

  # all OK, go ahead
  $out=retrieve($src)
  or throw "Error reading SHWL '$src'";

  return $out;
};


# ---   *   ---   *   ---
# reads symbol table entry

sub symtab_read($symtab,$lib,$path,$rebuild) {
  my $f=symrd($lib);

  # so regen check
  $$rebuild=ot($path,ffind('-l'.$lib))
  if ! $$rebuild;

  # add [file => object] entries
  for my $o(keys %{$f->{object}}) {
    my $obj=$f->{object}->{$o};
    my $key=Shb7::Path::root() . $o;

    $symtab->{object}->{$key}=$obj;
  };

  push @{$symtab->{dep}},$f->{dep};
  return;
};


# ---   *   ---   *   ---
# makes shared object based on
# the provided shadow lib

sub so_from_symtab($symtab,$path,@libs) {
  # get libraries
  map  {$ARG="-l$ARG"} @libs;
  push @libs,map {@$ARG} @{$symtab->{dep}};

  # reformat object field
  my @objs=map {
    {obj=>$ARG}

  } keys %{$symtab->{object}};


  # make struc for linking
  my $bld=__PACKAGE__->new(
    name    => $path,
    file    => \@objs,
    lib     => \@libs,
    shared  => 1,
    linking => 'cstd',
  );

  # ^rebuild if need and give
  $bld->olink() if $symtab->{rebuild};
  $symtab->{bld}=$bld;

  return;
};


# ---   *   ---   *   ---
# rebuilds shared objects if need be

sub soregen($name,$libs_ref,$no_regen=0) {
  my $path    = so($name);
  my $rebuild = ! -f $path;

  my @libs=@{$libs_ref};
  my $symtab={
    rebuild => 0,
    bld     => undef,
    dep     => [],
    object  => {}
  };


  # recover symbol table
  symtab_read($symtab,$ARG,$path,\$rebuild)
  for (@libs);

  # generate so
  $symtab->{rebuild}=$rebuild &&! $no_regen;
  so_from_symtab($symtab,$path,@libs);

  return $symtab;
};


# ---   *   ---   *   ---
1; # ret
