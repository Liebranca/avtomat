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

  use parent 'Shb7::Bk';

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang::C;

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
    q[-no-pie],
    q[-nostdlib],

  ];

# ---   *   ---   *   ---
# rebuild check

sub fupdated($self,$bfile) {

  my $do_build = !(-f $bfile->{obj});
  my @deps     = $self->fdeps($bfile);

  # no missing deps
  $bfile->depchk(\@deps);

  # make sure we need to update
  $bfile->buildchk(\$do_build,\@deps);

  return $do_build;

};

# ---   *   ---   *   ---
# get file dependencies

sub fdeps($self,$bfile) {

  my @out=($bfile->{src});

  if(!(-f $bfile->{dep})) {
    goto TAIL

  };

  # read file
  my $body=orc($bfile->{dep});

  # sanitize
  $body=~ s/\\//g;
  $body=~ s/\s/\,/g;
  $body=~ s/.*\://;

  # make
  @out=$self->depstr_to_array($body);

TAIL:
  return @out;

};

# ---   *   ---   *   ---

sub target($tgt) {

  my $out;

  if($tgt eq $Shb7::Bk::TARGET->{x64}) {
    $out=q[-m64];

  } elsif($tgt eq $Shb7::Bk::TARGET->{x32}) {
    $out=q[-m32];

  };

  return $out;

};

# ---   *   ---   *   ---
# C-style object file boiler

sub fbuild($self,$bfile,$bld) {

  say {*STDERR} Shb7::shpath($bfile->{src});

  my $up=$NULLSTR;
  if($bfile->{src}=~ $Lang::C::EXT_PP) {
    $up='-lstdc++';

  };

  if(-f $bfile->{obj}) {
    unlink $bfile->{obj};

  };

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

  array_filter(\@call);
  system {$call[0]} @call;

  return int(defined -f $bfile->{obj});

};

# ---   *   ---   *   ---
1; # ret
