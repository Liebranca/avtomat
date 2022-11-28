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

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Shb7::Path;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;
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

# ---   *   ---   *   ---
# global state

  our $Makedeps={
    objs=>[],
    deps=>[]

  };

# ---   *   ---   *   ---

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

sub module_deps($src) {

  my (@includes,@libpath,@libs);

  for my $lib(@$src) {

    my $path=$lib;

    # remove -l and get path to module
    $path=~ s[$Shb7::Path::LIBF_RE][];
    $path=dir($path);

    # retrieve build data if present
    if(-d $path) {

      my $meta=Shb7::Find::build_meta($path);

      push @includes,@{$meta->{incl}};
      push @libs,@{$meta->{libs}};

    };

  };

  for my $lib(@{$Shb7::Path::Lib}) {
    unshift @libs,q[-L].$lib;

  };

  for my $incl(reverse @{$Shb7::Path::Include}) {
    push @includes,q[-I].$incl;

  };

  return (\@includes,\@libs);

};

# ---   *   ---   *   ---
# object file linking

sub olink($objs,$name,%O) {

  # defaults
  $O{incl}   //= [];
  $O{libs}   //= [];
  $O{flags}  //= [];

  $O{shared} //= 0;
  $O{flat}   //= 0;

  my @flags=@{$O{flags}};

  unshift @flags,q[-shared]
  if $O{shared};

  my ($includes,$libs)=module_deps($O{libs});

  unshift @$includes,@{$O{incl}};
  unshift @$libs,@{$O{libs}};

  array_filter($includes,$FLGCHK);
  array_filter($libs,$FLGCHK);

  my @call=();

# ---   *   ---   *   ---

  # using gcc
  if(!$O{flat}) {

    @call=(

      q[gcc],

      @$OFLG,
      @$LFLG,
      @flags,

      q[-m64],

      @$includes,
      @$libs,

      @$objs,

      q[-o],$name

    );

  # gcc, but fine-tuned
  } elsif($O{flat} eq '1/2') {

    @call=(

      q[gcc],

      @$FLATLFLG,
      @flags,

      q[-m64],

      @$libs,
      @$includes,

      @$objs,

      q[-o],$name

    );

  # using ld ;>
  } else {

    @call=(

      q[ld.bfd],

      qw(--relax --omagic -d),
      qw(-e _start),

      qw(-m elf_x86_64),
      qw(--gc-sections),

      q[-o],$name,

      @$objs,
      @$libs,

    );

  };

  # link
  array_filter(\@call);
  system {$call[0]} @call;

};

# ---   *   ---   *   ---
1; # ret
