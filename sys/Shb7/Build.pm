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
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Build;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use Storable;
  use Readonly;
  use Carp;

  use Exporter 'import';

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::IO;

  use Shb7::Path;
  use Shb7::Find;

  use Shb7::Bk::gcc;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# adds to your namesopace

  our @EXPORT=qw(

    push_makedeps
    clear_makedeps

    obj_file
    obj_dir

  );

# ---   *   ---   *   ---
# ROM

  my $FLGCHK=sub {

     defined $ARG
  && 2<length $ARG

  };

# ---   *   ---   *   ---
# global state

  our $Makedeps={
    objs=>[],
    deps=>[]

  };

# ---   *   ---   *   ---
# constructor

sub nit($class,%O) {

  # defaults
  $O{name}   //= 'out';

  $O{files}  //= [];
  $O{incl}   //= [];
  $O{libs}   //= [];

  $O{shared} //= 0;
  $O{flat}   //= 0;
  $O{debug}  //= 0;
  $O{tgt}    //= $Shb7::Bk::TARGET->{x64};

# ---   *   ---   *   ---

  my $flags=[];

  unshift @$flags,q[-shared]
  if $O{shared};

  unshift @$flags,q[-g]
  if $O{debug};

# ---   *   ---   *   ---

  my $self=bless {

    name  => $O{name},
    files => $O{files},

    incl  => $O{incl},
    libs  => $O{libs},

    flags => $flags,
    flat  => $O{flat},
    tgt   => $O{tgt},

  },$class;

  $self->get_module_deps();
  $self->get_module_paths();

  return $self;

};

# ---   *   ---   *   ---
# adds to builder's file array

sub push_files($self,@data) {
  push @{$self->{files}},@data;

};

# ---   *   ---   *   ---
# adds to builder's flags array

sub push_flags($self,@data) {
  push @{$self->{flags}},@data;

};

# ---   *   ---   *   ---
# these are for generating mam's dependency lists
# in a nutshell: it's a hack

sub push_makedeps($obj,$dep) {
  push @{$Makedeps->{objs}},$obj;
  push @{$Makedeps->{deps}},$dep;

};

sub clear_makedeps() {
  $Makedeps={objs=>[],deps=>[]};

};

# ---   *   ---   *   ---
# shortcuts

sub obj_file($path) {
  return $Shb7::Path::Trash.$path

};

sub obj_dir($path=$NULLSTR) {
  return $Shb7::Path::Trash.$path.q[/];

};

# ---   *   ---   *   ---
# get dependencies for a module
# from build metadata

sub get_module_deps($self) {

  my @found=();
  my @paths=();

  array_filter($self->{libs});
  array_filter($self->{incl});

  while(@{$self->{libs}}) {

    # skip -L
    my $path=shift @{$self->{libs}};
    if($path=~ $LIBD_RE) {
      push @paths,$path;
      next;

    };

    my $lib=$path;

    # remove -l and get path to module
    $path=~ s[$LIBF_RE][];
    $path=dir($path);

    # retrieve build data if present
    if(-d $path) {

      my $meta=Shb7::Find::build_meta($path);

      push @{$self->{incl}},@{$meta->{incl}};
      push @found,@{$meta->{libs}},$lib;

    } else {
      push @found,$lib;

    };

  };

  push @{$self->{libs}},@paths;
  push @{$self->{libs}},@found;

};

# ---   *   ---   *   ---
# get current search paths

sub get_module_paths($self) {

  for my $lib(@{$Shb7::Path::Lib}) {
    unshift @{$self->{libs}},q[-L].$lib;

  };

  for my $incl(@{$Shb7::Path::Include}) {
    unshift @{$self->{incl}},q[-I].$incl;

  };

  array_filter($self->{incl},$FLGCHK);
  array_filter($self->{libs},$FLGCHK);

  array_dupop($self->{incl});
  array_dupop($self->{libs});

};

# ---   *   ---   *   ---
# return list of build files

sub list_obj($self) {
  return map {
    $ARG->{obj}

  } @{$self->{files}};

};

sub list_src($self) {
  return map {
    $ARG->{src}

  } @{$self->{files}};

};

sub list_dep($self) {
  return map {
    $ARG->{dep}

  } @{$self->{files}};

};

# ---   *   ---   *   ---
# standard call to link object files

sub link_common($self) {

  return (

    q[gcc],

    @{$Shb7::Bk::gcc::OFLG},
    @{$Shb7::Bk::gcc::LFLG},
    @{$self->{flags}},

    Shb7::Bk::gcc::target($self->{tgt}),

    @{$self->{incl}},
    $self->list_obj(),

    q[-o],$self->{name},
    @{$self->{libs}},

  );

};

# ---   *   ---   *   ---
# ^similar, but fine-tuned for nostdlib
# what I *usually* use with assembler *.o files

sub link_hflat($self) {

  return (

    q[gcc],

    @{$Shb7::Bk::gcc::FLATLFLG},
    @{$self->{flags}},

    Shb7::Bk::gcc::target($self->{tgt}),

    @{$self->{incl}},
    $self->list_obj(),

    q[-o],$self->{name},
    @{$self->{libs}},

  );

};

# ---   *   ---   *   ---
# extreme ld-only setup
# meant for teensy assembler binaries

sub link_flat($self) {

  return (

    q[ld.bfd],

    qw(--relax --omagic -d),
    qw(-e _start),

    qw(-m elf_x86_64),
    qw(--gc-sections),

    q[-o],$self->{name},

    $self->list_obj(),
    @{$self->{libs}},

  );

};

# ---   *   ---   *   ---
# object file linking

sub olink($self) {

  my @call=();

  # using gcc
  if(!$self->{flat}) {
    @call=$self->link_common();

  # gcc, but fine-tuned
  } elsif($self->{flat} eq '1/2') {
    @call=$self->link_hflat();

  # using ld ;>
  } else {
    @call=$self->link_flat();

  };

  array_filter(\@call);
  system {$call[0]} @call;

};

# ---   *   ---   *   ---
# symrd errme

sub throw_no_shwl($name,$path) {

  errout(

    q[Can't find shadow lib for '%s' <%s>],

    args => [$name,$path],
    lvl  => $AR_ERROR,

  );

};

# ---   *   ---   *   ---
# get symbol typedata from shadow lib

sub symrd($mod) {

  my $out={};
  my $src=libdir().".$mod";

  # existence check
  if(! -f $src) {
    throw_no_shwl($mod,$src);
    goto TAIL;

  };

  $out=retrieve($src)
  or croak strerr($src);

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# reads symbol table entry

sub symtab_read(

  $symtab,

  $lib,
  $path,
  $rebuild

) {

  my $f=symrd($lib);

  # so regen check
  if(!$$rebuild) {
    $$rebuild=ot($path,ffind('-l'.$lib));

  };

  # append
  for my $o(keys %{$f->{objects}}) {

    my $obj=$f->{objects}->{$o};

    $symtab->{objects}->{
      $Shb7::Path::Root.$o

    }=$obj;

  };

  push @{$symtab->{deps}},$f->{deps};

};

# ---   *   ---   *   ---
# creates a shared object based on
# the provided shwl symbol table

sub so_from_symtab($symtab,$path,@libs) {

  map {$ARG="-l$ARG"} @libs;
  @libs=(@libs,@{$symtab->{deps}});

  my $bld=Shb7::Build->nit(

    name   => $path,

    objs   => $symtab->{objects},
    libs   => \@libs,

    shared => 1,
    flat   => 0,

  );

  $bld->olink();

};

# ---   *   ---   *   ---
# rebuilds shared objects if need be

sub soregen($name,$libs_ref,$no_regen=0) {

  my $path    = so($name);
  my $rebuild = ! -f $path;

  my @libs=@{$libs_ref};
  my $symtab={

    deps=>[],
    objects=>{}

  };

  # recover symbol table
  for my $lib(@libs) {
    symtab_read($symtab,$lib,$path,\$rebuild);

  };

  # generate so
  if($rebuild && !$no_regen) {
    so_from_symtab($symtab,$path,@libs);

  };

  return $symtab;

};

# ---   *   ---   *   ---
1; # ret
