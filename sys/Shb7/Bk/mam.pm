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

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";

  use Style qw(null);
  use Arstd::Path qw(dirof reqdir);
  use Arstd::Bin qw(ot orc owc);

  use Log;

  use Shb7::Path qw(root relto_root);
  use Shb7::Bfile;
  use Shb7::Build;
  use parent 'Shb7::Bk';

  use lib "$ENV{ARPATH}/lib";
  use MAM;


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

    obj_ext => 'pm',
    dep_ext => 'pmd',
    asm_ext => undef,
  );

  return $self->{file}->[-1];
};


# ---   *   ---   *   ---
# Perl-style rebuild check

sub fupdated($self,$bfile,%O) {
  state $is_mam=qr{MAM\.pm$};

  # don't rebuild the source filter ;>
  return 0 if $bfile->{src}=~ $is_mam;

  # ^else procceed
  my $do_build=(
     (! -f $bfile->{obj})
  || ot($bfile->{obj},$bfile->{src})
  );

  my @deps=$self->fdeps($bfile);


  # no missing deps
  $bfile->depchk(\@deps);

  # make sure we need to update
  $bfile->buildchk(\$do_build,\@deps);

  # depsmake hash needs to know
  # if this one requires attention
  Shb7::Build::push_makedeps(
    $bfile->{obj},
    $bfile->{dep},

  ) if (! -f $bfile->{dep}) || $do_build;

  return $do_build;
};


# ---   *   ---   *   ---
# makes file list out of *.pmd files

sub fdeps($self,$bfile) {
  return () if ! -f $bfile->{dep};
  my @out=();

  # read
  my $body  = orc $bfile->{dep};
  my $fname = null;

  # assign
  ($fname,$body)=split qr"\n",$body;

  # make and give
  @out=$self->depstr_to_array($body)
  if $fname && $body;

  return @out;
};


# ---   *   ---   *   ---
# makes MAM ice

sub on_build($self,$bld,@bfile) {
  $ENV{MAMROOT}=root();

  my $mam=MAM->new();
  $mam->set_module(Shb7::Path::module());
  $mam->set_rap(1);

  # add libs to path
  my $libd_re = Shb7::Path::libd_re();
  my $inc_re  = Shb7::Path::inc_re();

  # ... but first remove "-L" || "-I"
  my @lib=(
    @{$bld->{inc}},
    grep {$ARG=~ $libd_re} @{$bld->{lib}}
  );

  for(@lib) {
    $ARG=~ s[$libd_re][];
    $ARG=~ s[$inc_re][];
  };

  # ^now add the libs ;>
  $mam->libpush(@lib);

  # store MAM ice within self
  $self->{-MAM}=$mam;
  return @bfile;
};


# ---   *   ---   *   ---
# ^uses MAM ice to build file list

sub build_objects($self,$bld,@bfile) {
  Log->ex("MAM","Perl preprocessor:");

  # first step
  for(@bfile) {
    $self->log_fpath($ARG->{src});
    $self->fbuild($ARG,$bld);
  };

  # ^with all files handled, now go again
  Log->step("^running second pass");
  $self->{-MAM}->set_rap(0);
  for(@bfile) {
    $self->log_fpath($ARG->{obj});
    $self->fbuild($ARG,$bld);
  };

  delete $self->{-MAM};
  return (0);
};


# ---   *   ---   *   ---
# Perl "building"
#
# it's just a preprocessor step
# (see: MAM.pm)

sub fbuild($self,$bfile,$bld) {
  my $mam=$self->{-MAM};
  my ($dst,$src)=($mam->{rap})
    ? ($bfile->{obj},$bfile->{src})
    : ($bfile->{out},$bfile->{obj})
    ;

  owc $dst,$mam->run($dst,$src);
  return 0;
};


# ---   *   ---   *   ---
1; # ret
