#!/usr/bin/perl
# ---   *   ---   *   ---
# BK FLAT
# Wrappers for fasm+ld ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::flat;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_file);

  use Arstd::Path qw(extwap);
  use Arstd::Bin qw(orc);
  use Arstd::throw;

  use Shb7::Path qw(relto_root);

  use Log;
  use parent 'Shb7::Bk';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# add entry to build files

sub push_src($self,$fpath) {
  push @{$self->{file}},Shb7::Bfile->new(
    $fpath,
    $self,

    obj_ext=>'o',
    dep_ext=>'asmd',
    asm_ext=>undef,
  );

  return $self->{file}->[-1];
};


# ---   *   ---   *   ---
# get variant of arch flag

sub target($tgt) {
  my @out=();

  if($tgt eq Shb7::Bk->target_arch('x64')) {
    @out=qw(-m elf_x86_64);

  } elsif($tgt eq Shb7::Bk->target_arch('x86')) {
    @out=qw(-m elf_x86);

  };

  return @out;
};


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
  if(is_file($bfile->{dep})) {
    my $body=orc($bfile->{dep});
    @out=split qr"\n",$body;
  };

  return @out;
};


# ---   *   ---   *   ---
# get variant of entry flag

sub entry($name) {return ('-e',$name)};


# ---   *   ---   *   ---
# object file boiler

sub fbuild($self,$bfile,$bld) {
  my $oomre=qr{error: out of memory\.};
  my $merrf='./.bkflat.tmp';

  my $rel=$bfile->{src};
  relto_root($rel);
  Log->substep($rel);

  # clear existing
  $bfile->prebuild();

  # assemble
  $self->asm($bfile->{src},$merrf);

  # ^reloc out if exists
  my $out=extwap($bfile->{src},'o');
  rename $out,$bfile->{obj} if -f $out;


  # using standard output format?
  my $chk=(defined $bfile->{__alt_out})
    ? $bfile->{__alt_out}
    : $bfile->{obj}
    ;

  # ^throw on failure
  throw "FLAT: build fail" if ! is_file($chk);

  # standard binary generated
  if($chk eq $bfile->{obj}) {
    $bfile->postbuild();

  # ^else it's fun stuff!
  } else {
    $bfile->binfilter();
    $bfile->postbuild();

  };

  return 1;
};


# ---   *   ---   *   ---
# invokes fasm!

sub asm($class,$src,$merrf,@args) {

# ---   *   ---   *   ---
# NOTE:
#
#   no good way to estimate memory
#   req for assembling a file, afaik
#
#   so we just iter and increase
#   it from the default 16K

  my $oomre=qr{error: out of memory\.};
  my @sztab=(
    2 ** 13 , 2 ** 14 , 2 ** 16 , 2 ** 17
  );

  my $attp = 0;
  my $mem  = null;


  # ^top
  MEM_RECALC:

  $mem="-m $sztab[$attp]";

  # invoke cmd and save error to tmp file
  `fasm $mem @args $src 2> $merrf`;
  my $merr=orc($merrf);

  # ^catch "out of memory" errme
  ++$attp;

  goto MEM_RECALC
  if ($attp < @sztab) && ($merr=~ $oomre);


  # ^unsolved err
  throw $merr if length $merr;

  # ^all good ;>
  return 1;
};


# ---   *   ---   *   ---
1; # ret
