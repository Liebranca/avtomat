#!/usr/bin/perl
# ---   *   ---   *   ---
# BK GCC
# Wrappers for C builds
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::gcc;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_file);

  use Arstd::Array qw(filter);
  use Arstd::Bin qw(orc);

  use Shb7::Path qw(relto_root);
  use Ftype::Text::C;

  use Log;
  use parent 'Shb7::Bk';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub oflg {return qw(
  -O2
  -fpermissive
  -w
  -ftree-vectorize
  -fno-unwind-tables
  -fno-eliminate-unused-debug-symbols
  -fno-asynchronous-unwind-tables
  -ffast-math
  -fsingle-precision-constant
  -fno-ident
  -fPIC
)};

sub lflg {return qw(
  -fpermissive
  -w
  -flto
  -ffunction-sections
  -fdata-sections
), (
  '-Wl,--gc-sections',
  '-Wl,-fuse-ld=bfd',
)};

sub flatflg {return qw(
  -fpermissive
  -w
  -flto
  -ffunction-sections
  -fdata-sections
  -no-pie
  -nostdlib
), (
  '-Wl,--gc-sections',
  '-Wl,-fuse-ld=bfd',
  '-Wl,--relax,-d',
  '-Wl,--entry=_start',
)};


# ---   *   ---   *   ---
# rebuild chk

sub fupdated($self,$bfile) {
  return $self->chkfdeps($bfile);
};


# ---   *   ---   *   ---
# get file dependencies

sub fdeps($self,$bfile) {
  my @out=($bfile->{src});

  # read file if it exists
  my $bslash_re=qr{\\};
  my $nspace_re=qr{\s+};
  my $colon_re=qr{.*\:};
  if(is_file($bfile->{dep})) {
    my $body=orc($bfile->{dep});

    # sanitize
    $body=~ s[$bslash_re][]g;
    $body=~ s[$nspace_re][,]g;
    $body=~ s[$colon_re][];

    # make array from gcc depsfile
    @out=$self->depstr_to_array($body);
  };

  return @out;
};


# ---   *   ---   *   ---
# get variant of arch flag

sub target($tgt) {
  my $out;
  if($tgt eq Shb7::Bk->target_arch('x64')) {
    $out='-m64';

  } elsif($tgt eq Shb7::Bk->target_arch('x86')) {
    $out='-m32';
  };

  return $out;
};


# ---   *   ---   *   ---
# get variant of entry flag

sub entry($name) {return "-Wl,--entry=$name"};


# ---   *   ---   *   ---
# C-style object file boiler

sub fbuild($self,$bfile,$bld) {
  my $rel=$bfile->{src};
  relto_root($rel);
  Log->substep($rel);

  # conditionally use octopus
  my $cpp=Ftype::Text::C->is_cpp($bfile->{src});
  my $up=($cpp)
    ? '-lstdc++'
    : null
    ;

  # clear existing
  $bfile->prebuild();


  # cstruc cmd
  my @call=(
    ($cpp) ? q[g++] : q[gcc] ,

    '-MMD',
    target($bld->{tgt}),

    (map {"-D$ARG"} @{$bld->{def}}),

    @{$bld->{flag}},
    oflg(),

    @{$bld->{inc}},
    $up,

    "-Wa,-a=$bfile->{asm}",
    -c => $bfile->{src},
    -o => $bfile->{obj},

    @{$bld->{lib}},
  );


  # ^cleanup and invoke
  filter(\@call);
  system {$call[0]} @call;


  # ^give on success
  return int(defined is_file($bfile->{obj}));
};


# ---   *   ---   *   ---
1; # ret
