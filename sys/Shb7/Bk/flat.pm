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
  use Arstd::String;
  use Arstd::Path;
  use Arstd::IO;

  use Arstd::WLog;

  use parent 'Shb7::Bk';
  use lib $ENV{'ARPATH'}.'/lib/';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# add entry to build files

sub push_src($self,$fpath) {

  push @{$self->{files}},

  Shb7::Bfile->new(

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
# invokes fasm!

sub asm($class,$src,$merrf,@args) {

# ---   *   ---   *   ---
# NOTE:
#
#   no good way to estimate memory
#   req for assembling a file, afaik
#
#   so we just iter and increase
#   the ammout from the default 16K

  state $oomre = qr{error: out of memory\.};
  state @sztab = (

#    map {1024 + (1024*$ARG)} 0..127
    2 ** 13 , 2 ** 14 , 2 ** 16 , 2 ** 17

  );

  my $attp = 0;
  my $mem  = $NULLSTR;

# ---   *   ---   *   ---
# ^top

MEM_RECALC:

  $mem="-m $sztab[$attp]";

use Benchmark;
my $t0 = Benchmark->new;

  # invoke cmd and save error to tmp file
  `fasm $mem @args $src &> $merrf`;

my $t1 = Benchmark->new;
my $td = timediff($t1,$t0);

my $tt = timestr($td,'nop','8.16f');
strip(\$tt);

$tt=~ s[.+([0-9]+\.[0-9]+) \s CPU.+$][$1]x;
$tt= sprintf "%8.2f",$tt*1000;

$WLog->substep("took $tt ms\n");

  my $merr=orc($merrf);

  # ^catch "out of memory" errme
  $attp++;

  goto MEM_RECALC
  if ($attp < @sztab) && ($merr=~ $oomre);


  # ^unsolved err
  if(length $merr) {
    say {*STDERR} $merr;
    return 0;

  # ^all good ;>
  } else {
    return 1;

  };

}

# ---   *   ---   *   ---
