#!/usr/bin/perl
# ---   *   ---   *   ---
# BFILE
# Intermediate stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Bfile;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Readonly;

  use Exporter 'import';

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::IO;

  use Shb7;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# adds to your namespace

  our @EXPORT=qw(

    $AVTOPATH

  );

# ---   *   ---   *   ---
# ROM

  Readonly our $AVTOPATH=>
    $ENV{'ARPATH'}.'/avtomat/';

  Readonly our $LDOK_RE=>qr{

    Shb7\:\:Bk\:\:(?: gcc|fasm)

  }x;

# ---   *   ---   *   ---
# constructor

sub nit($class,$fpath,$bk,%O) {

  $O{out}//=$NULLSTR;

  my $self=bless {

    src => $fpath,

    out => $O{out},
    bk  => $bk,

    obj => Shb7::obj_from_src(
      $fpath,
      ext=>$O{obj_ext}

    ),

    dep => Shb7::obj_from_src(
      $fpath,
      ext=>$O{dep_ext}

    ),

    asm => Shb7::obj_from_src(
      $fpath,
      ext=>$O{asm_ext}

    ),

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# build output is valid ld input

sub linkable($self) {

  my $class=ref $self->{bk};
  return int($class=~ $LDOK_RE);

};

# ---   *   ---   *   ---
# give 1 if object was rebuilt

sub update($self,$bld) {

  my $out=0;

  if($self->{bk}->fupdated($self)) {
    $out=$self->{bk}->fbuild($self,$bld);

  };

  return $out;

};

# ---   *   ---   *   ---
# check object date against dependencies

sub buildchk($self,$do_build,$deps) {

  if(!$$do_build) {
    while(@$deps) {

      my $dep=shift @$deps;
      if(!(-f $dep)) {next};

      # found dep is updated
      if(Shb7::ot($self->{obj},$dep)) {
        $$do_build=1;
        last;

      };

    };

  };

};

# ---   *   ---   *   ---
# sanity check: dependency files exist

sub depchk($self,$deps) {

  for my $dep(@$deps) {

    if($dep && !(-f $dep)) {

      errout(

        "%s missing dependency %s\n",

        args=>[
          Shb7::shpath($self->{src}),
          $dep

        ],

        lvl=>$AR_FATAL,

      );

    };

  };

};

# ---   *   ---   *   ---
1; # ret
