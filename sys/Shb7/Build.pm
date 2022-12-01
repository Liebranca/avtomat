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
  use Readonly;
  use Carp;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;

  use Shb7::Path;
  use Shb7::Find;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $OFLG=>[
    q[-Os],
    q[-fno-unwind-tables],
    q[-fno-eliminate-unused-debug-symbols],
    q[-fno-asynchronous-unwind-tables],
    q[-ffast-math],
    q[-fsingle-precision-constant],
    q[-fno-ident],
    q[-fPIC],

  ];

  Readonly our $LFLG=>[
    q[-flto],
    q[-ffunction-sections],
    q[-fdata-sections],
    q[-Wl,--gc-sections],
    q[-Wl,-fuse-ld=bfd],

  ];

  Readonly our $FLATLFLG=>[
    q[-flto],
    q[-ffunction-sections],
    q[-fdata-sections],
    q[-Wl,--gc-sections],
    q[-Wl,-fuse-ld=bfd],

    q[-Wl,--relax,-d],
    q[-Wl,--entry=_start],
    q[-no-pie -nostdlib],

  ];

  my $FLGCHK=sub {

     defined $ARG
  && 2<length $ARG

  };

  Readonly our $BACKEND=>{
    fasm => 0,
    gcc  => 1,
    mam  => 2

  };

  Readonly our $TARGET=>{
    x64=>0,
    x32=>1,

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

  $O{incl}   //= [];
  $O{libs}   //= [];

  $O{files}  //= [];
  $O{shared} //= 0;
  $O{back}   //= $BACKEND->{gcc};
  $O{flat}   //= 0;
  $O{tgt}    //= $TARGET->{x64};

  my $flags=[];

  unshift @$flags,q[-shared]
  if $O{shared};

  my $self=bless {

    name  => $O{name},

    files => $O{files},

    incl  => $O{incl},
    libs  => $O{libs},

    flags => $flags,
    back  => $O{back},
    flat  => $O{flat},
    tgt   => $O{plat},

  },$class;

  $self->get_module_deps();
  $self->get_module_paths();

  return $self;

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

  while(@{$self->{libs}}) {

    # skip -L
    my $path=shift @{$self->{libs}};
    if($path=~ $LIBD_RE) {
      push @paths,$path;
      next;

    };

    # remove -l and get path to module
    $path=~ s[$LIBF_RE][];
    $path=dir($path);

    # retrieve build data if present
    if(-d $path) {

      my $meta=Shb7::Find::build_meta($path);

      push @{$self->{incl}},@{$meta->{incl}};
      push @found,@{$meta->{libs}};

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

};

# ---   *   ---   *   ---
# return list of build files

sub list_obj($self) {
  return map {$ARG->{obj}} @{$self->{files}};

};

sub list_src($self) {
  return map {$ARG->{src}} @{$self->{files}};

};

sub list_dep($self) {
  return map {$ARG->{dep}} @{$self->{files}};

};

# ---   *   ---   *   ---
# barebones platform switch

sub target($self) {

  state $choice=[
    undef,
    \&gcc_target,
    undef

  ];

  return $choice[$self->{back}]->();

};

# ---   *   ---   *   ---
# ^backend is gcc

sub gcc_target($self) {

  my $out;
  if($self->{tgt} eq $TARGET->{x64}) {
    $out=q[-m64];

  } elsif($self->{tgt} eq $TARGET->{x32}) {
    $out=q[-m32];

  };

  return $out;

};

# ---   *   ---   *   ---
# src to [obj|dep|asm]

sub build_obj($self,$idex) {

  state $choice=[
    undef,
    \&gcc_build_obj,
    undef

  ];

  my $bfile=$self->{files}->[$idex];
  return $choice[$self->{back}]->($bfile);

};

# ---   *   ---   *   ---
# ^backend is gcc

sub gcc_build_obj($self,$bfile) {

  return (

    q[gcc],
    q[-MMD],
    $self->target(),

    @$OFLG,

    @{$self->{flags}},
    @{$self->{incl}},
    @{$self->{libs}},

    q[-Wa,-a=].$bfile->{asm},

    q[-c],$bfile->{src},
    q[-o],$bfile->{obj}

  );

};

# ---   *   ---   *   ---
# standard call to link object files

sub link_common($self) {

  return (

    q[gcc],

    @$OFLG,
    @$LFLG,
    @{$self->{flags}},

    q[-m64],

    @{$self->{incl}},
    @{$self->{libs}},

    $self->list_obj(),

    q[-o],$self->{name}

  );

};

# ---   *   ---   *   ---
# ^similar, but fine-tuned for nostdlib
# what I *usually* use with assembler *.o files

sub link_hflat($self) {

  return (

    q[gcc],

    @$FLATLFLG,
    @{$self->{flags}},

    q[-m64],

    @{$self->{libs}},
    @{$self->{incl}},

    $self->list_obj(),

    q[-o],$self->{name}

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

sub throw_no_shwl($name) {

  errout(

    q[Can't find shadow lib for '%s'],

    args => [$name],
    lvl  => $AR_ERROR,

  );

};

# ---   *   ---   *   ---
# get symbol typedata from shadow lib

sub symrd($mod) {

  my $out={};
  my $src=lib(".$mod");

  # existence check
  if(! -f $src) {
    throw_no_shwl($mod);
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
    $$rebuild=ot($path,ffile('-l'.$lib));

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
    symtab_regen($symtab,$path,@libs);

  };

  return $symtab;

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
  clear_dir("$Shb7::Path::Trash$name/",-r=>1);

};

# ---   *   ---   *   ---
1; # ret
