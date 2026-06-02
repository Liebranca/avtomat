#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO BFILE
# Intermediate stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::bfile;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);
  use St qw(is_valid);

  use Arstd::String qw(cat catpath cjag);
  use Arstd::Bin qw(moo);
  use Arstd::Path qw(dirof reqdir);
  use Arstd::throw;

  use Shb7::Path qw(root relto_root);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# cstruc

sub new {
  my ($class,$fpath,%O)=@_;

  # get files produced by source
  my @have=();
  for(qw(obj dep asm)) {
    if(is_null($O{$ARG})) {
      push @have,$ARG=>null;

    } else {
      push @have,$ARG=>Shb7::Path::obj_from_src(
        $fpath,
        rel=>0,
        ext=>$O{$ARG}
      );
    };
  };

  # ^save files to single struc
  my $bfile=bless {src=>$fpath,@have},$class;
  return $bfile;
};


# ---   *   ---   *   ---
# check object date against dependencies

sub depchk {
  my ($bfile,$dep)=@_;

  # first off ensure there are
  # no missing deps
  $bfile->depok($dep);

  # early exit if source is updated
  return 1 if moo($bfile->{obj},$bfile->{src});

  # ^repeat check for each dependency
  for(@$dep) {
    return 1 if moo($bfile->{obj},$ARG);
  };
  # else no rebuild is needed
  return 0;
};


# ---   *   ---   *   ---
# sanity check: dependency files exist

sub depok {
  my ($bfile,$dep)=@_;

  # ok if no missing deps
  my @miss=grep {$ARG &&! is_file($ARG)} @$dep;
  return 1 if! @miss;

  # ^give errme
  my $rel=$bfile->{src};
  relto_root($rel);

  throw "avto: $rel missing dependencies\n"
  .     cjag("\n::",@miss);
};


# ---   *   ---   *   ---
# give list of paths

sub unroll {
  my ($bfile,@key)=@_;
  return map {$bfile>{$ARG}} @key;
};


# ---   *   ---   *   ---
# ensures that all target directories
# for this file exist

sub ensure_outdirs {
  my ($bfile)=@_;
  for(qw(asm obj dep)) {
    next if is_null($bfile->{$ARG});

    my $path=catpath(root(),dirof($bfile->{$ARG}));
    reqdir($path);
  };
  return;
};


# ---   *   ---   *   ---
1; # ret
