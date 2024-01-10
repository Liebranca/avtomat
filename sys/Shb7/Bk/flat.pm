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
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::flat;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::Path;
  use Arstd::IO;

  use Arstd::WLog;

  use parent 'Shb7::Bk';
  use lib $ENV{'ARPATH'}.'/lib/';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# add entry to build files

sub push_src($self,$fpath) {

  push @{$self->{files}},

  Shb7::Bfile->nit(

    $fpath,
    $self,

    obj_ext=>q[.o],
    dep_ext=>q[.asmd],
    asm_ext=>undef,

  );

  return $self->{files}->[-1];

};

# ---   *   ---   *   ---
# get variant of arch flag

sub target($tgt) {

  my @out=();

  if($tgt eq $Shb7::Bk::TARGET->{x64}) {
    @out=qw(-m elf_x86_64);

  } elsif($tgt eq $Shb7::Bk::TARGET->{x32}) {
    @out=qw(-m elf_x86);

  };

  return @out;

};

# ---   *   ---   *   ---
# rebuild chk

sub fupdated($self,$bfile) {
  $self->chkfdeps($bfile);

};

# ---   *   ---   *   ---
# get file dependencies

sub fdeps($self,$bfile) {

  my @out=($bfile->{src});

  goto TAIL if ! -f $bfile->{dep};

  # read file
  my $body=orc($bfile->{dep});
  @out=split $NEWLINE_RE,$body;


TAIL:
  return @out;

};

# ---   *   ---   *   ---
# get variant of entry flag

sub entry($name) {return ('-e',$name)};

# ---   *   ---   *   ---
# object file boiler

sub fbuild($self,$bfile,$bld) {

  state $oomre=qr{error: out of memory\.};
  state $merrf='./.bkflat.tmp';


  $WLog->substep(Shb7::shpath($bfile->{src}));

  # clear existing
  $bfile->prebuild();

# ---   *   ---   *   ---
# NOTE:
#
#   no good way to estimate memory
#   req for assembling a file, afaik
#
#   so we just iter and increase
#   the ammout from the default 16K

  my $size = 14;
  my $mem  = $NULLSTR;

# ---   *   ---   *   ---
# ^top

MEM_RECALC:

  $mem='-m '.(2 ** $size++);

  # invoke cmd and save error to tmp file
  `fasm $mem $bfile->{src} 2> $merrf`;
  my $merr=orc($merrf);

  # ^catch "out of memory" errme
  goto MEM_RECALC
  if ($size < 18) && ($merr=~ $oomre);


  # ^reloc out if exists
  my $out=extwap($bfile->{src},'o');
  rename $out,$bfile->{obj} if -f $out;

  say {*STDERR} $merr if length $merr;

  my $chk=(defined $bfile->{__alt_out})
    ? $bfile->{__alt_out}
    : $bfile->{obj}
    ;


  # ^give on success
  if(-f $chk) {

    # standard binary generated
    if($chk eq $bfile->{obj}) {
      $bfile->postbuild();

    # ^else it's fun stuff!
    } else {
      $bfile->binfilter();
      $bfile->postbuild();

    };

    return 1;

  } else {
    errout("FLAT: build fail",lvl=>$AR_FATAL);
    return 0;

  };

};

# ---   *   ---   *   ---
