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
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::gcc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::IO;

  use Arstd::WLog;

  use parent 'Shb7::Bk';

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang::C;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $OFLG=>[

# NOTE
#
# testing if -O3 gives us
# better performance
#
# ftree-vectorize and other
# flags would then be on by
# default, but afaik *not*
# if we use -Os instead
#
# so, i'll leave the flags in
# case we switch back
#
#    q[-Os],

    q[-O3],

    q[-ftree-vectorize],
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
    q[-no-pie],
    q[-nostdlib],

  ];

# ---   *   ---   *   ---
# rebuild chk

sub fupdated($self,$bfile) {
  $self->chkfdeps($bfile);

};

# ---   *   ---   *   ---
# get file dependencies

sub fdeps($self,$bfile) {

  my @out=($bfile->{src});

  # read file if it exists
  if(-f $bfile->{dep}) {

    my $body=orc($bfile->{dep});

    # sanitize
    $body=~ s/\\//g;
    $body=~ s/\s/\,/g;
    $body=~ s/.*\://;

    # make array from gcc depsfile
    @out=$self->depstr_to_array($body);

  };


  return @out;

};

# ---   *   ---   *   ---
# get variant of arch flag

sub target($tgt) {

  my $out;

  if($tgt eq Shb7::Bk->TARGET->{x64}) {
    $out=q[-m64];

  } elsif($tgt eq Shb7::Bk->TARGET->{x32}) {
    $out=q[-m32];

  };

  return $out;

};

# ---   *   ---   *   ---
# get variant of entry flag

sub entry($name) {return "-Wl,--entry=$name"};

# ---   *   ---   *   ---
# C-style object file boiler

sub fbuild($self,$bfile,$bld) {

  $WLog->substep(Shb7::shpath($bfile->{src}));


  # conditionally use octopus
  my $up=($bfile->{src}=~ $Lang::C::EXT_PP)
    ? '-lstdc++'
    : $NULLSTR
    ;

  # clear existing
  $bfile->prebuild();


  # cstruc cmd
  my @call=(

    q[gcc],

    q[-MMD],
    target($bld->{tgt}),

    @{$bld->{flags}},
    @$OFLG,

    @{$bld->{incl}},
    $up,

    q[-Wa,-a=].$bfile->{asm},

    q[-c],$bfile->{src},
    q[-o],$bfile->{obj},

    @{$bld->{libs}},

  );


  # ^cleanup and invoke
  array_filter(\@call);
  system {$call[0]} @call;

  # ^give on success
  return int(defined -f $bfile->{obj});

};

# ---   *   ---   *   ---
1; # ret
