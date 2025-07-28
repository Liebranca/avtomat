#!/usr/bin/perl
# ---   *   ---   *   ---
# BK MAM
# Wrappers for Perl "builds"
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::mam;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;

  use Arstd::Path qw(dirof reqdir);
  use Arstd::IO qw(orc owc);

  use Arstd::WLog;

  use Shb7;
  use Shb7::Path;
  use Shb7::Bfile;

  use parent 'Shb7::Bk';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# add entry to build files

sub push_src($self,$fpath,$fout) {
  push @{$self->{file}},Shb7::Bfile->new(
    $fpath,
    $self,

    out     => $fout,

    obj_ext => q[.pm],
    dep_ext => q[.pmd],
    asm_ext => undef,

  );

  return $self->{file}->[-1];

};


# ---   *   ---   *   ---
# Perl-style rebuild check

sub fupdated($self,$bfile) {
  state $is_mam=qr{MAM\.pm$};

  # don't rebuild the source filter ;>
  return 0 if $bfile->{src}=~ $is_mam;

  # ^else procceed
  my $do_build=(
     (! -f $bfile->{obj})
  || Shb7::ot($bfile->{obj},$bfile->{src})
  );

  my @deps=$self->fdeps($bfile);


  # no missing deps
  $bfile->depchk(\@deps);

  # make sure we need to update
  $bfile->buildchk(\$do_build,\@deps);

  # depsmake hash needs to know
  # if this one requires attention
  if((! -f $bfile->{dep}) || $do_build) {

    Shb7::push_makedeps(
      $bfile->{obj},$bfile->{dep}

    );

  };


  return $do_build;

};


# ---   *   ---   *   ---
# makes file list out of pcc .pmd files

sub fdeps($self,$bfile) {
  return () if ! -f $bfile->{dep};
  my @out=();

  # read
  my $body  = orc $bfile->{dep};
  my $fname = null;

  # assign
  ($fname,$body)=split $NEWLINE_RE,$body;


  # make and give
  @out=$self->depstr_to_array($body)
  if $fname && $body;

  return @out;

};


# ---   *   ---   *   ---
# shorthand for this big ole bashit

sub mamcall($self,$bfile,$bld,$rap=1) {
  my @libpaths=grep {
    $ARG=~ $LIBD_RE

  } @{$bld->{lib}};


  map {$ARG=~ s[$LIBD_RE][-I]} @libpaths;

  $rap=($rap)
    ? q[--rap,]
    : null
    ;

  my @call=(
    perl => '-c',

    '-I' . Shb7::dir($Shb7::Path::Cur_Module),

    @{$bld->{inc}},
    @libpaths,

    "-MMAM=$rap--module=$Shb7::Path::Cur_Module",

    $bfile->{src}

  );

  return @call;

};


# ---   *   ---   *   ---
# Perl "building"
#
# actually it's applying any
# custom source filters

sub fbuild($self,$bfile,$bld,$rap=1) {
  $WLog->substep(
    Shb7::shpath($bfile->{src})

  ) if $rap;

  my @call = $self->mamcall($bfile,$bld,$rap);

  my $ex   = join q[ ],@call;
  my $root = $bfile->AVTOPATH;
  my $out  = `$ex 2> $root/.errlog`;

  if(! length $out) {
    my $log=orc "$root/.errlog";
    $WLog->err(
      'failed to apply filters',

      from    => 'MAM',
      details => $log,

      lvl     => $AR_FATAL,

    );

  };

  # make directories if need
  map {reqdir dirof $ARG if ! -f $ARG}
  ($bfile->{obj},$bfile->{dep});

  owc $bfile->{obj},$out;


  if($rap) {
    $bfile->{src}=$bfile->{obj};
    $bfile->{obj}=$bfile->{out};

    $self->fbuild($bfile,$bld,0);

  };

  return 0;

};


# ---   *   ---   *   ---
1; # ret
