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

package avto::bk::MAM;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Arstd::String qw(gsplit);
  use Arstd::Path qw(dirof reqdir);
  use Arstd::Bin qw(moo orc owc);

  use Log;

  use Shb7::Path qw(root relto_root);

  use lib "$ENV{ARPATH}/lib";
  use AR;
  use MAM;
  use parent 'avto::bk';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub obj_ext {return 'pm'};
sub dep_ext {return 'pmd'};
sub asm_ext {return null};


# ---   *   ---   *   ---
# cstruc
#
# TODO avto::bk has a 'pproc' attr,
#
#      so we could rewrite this to
#      allow for switching to a different
#      preprocessor
#
#      this isn't really a necessity right now,
#      but i'll put it here as a reminder

sub new {
  # call super
  my ($class,$px,%O)=@_;
  my $bk=avto::bk::new($class,$px,%O);

  # make pproc ice
  my $pproc=MAM->new();

  # add libs to path
  $pproc->libpush(
    @{$px->{lib}->{dir}},
    @{$px->{inc}},
  );

  # store pproc ice within self
  $bk->{pproc}=$pproc;
  return $bk;
};


# ---   *   ---   *   ---
# makes file list out of *.pmd files

sub fdeps {
  my ($bk,$bfile)=@_;
  return () if! is_file($bfile->{dep});

  # read
  my $body  = orc($bfile->{dep});
  my $fname = null;

  # assign
  ($fname,$body)=split qr"\n",$body;

  # make and give
  return($fname && $body)
    ? gsplit($body,qr{\s*,\s*})
    : ()
    ;
};


# ---   *   ---   *   ---
# ^uses MAM ice to build file list

sub build_objects {
  my ($bk,$sw,@bfile)=@_;
  Log->ex("MAM","Perl preprocessor:");

  # setup pproc
  $ENV{MAMROOT}=root();
  $bk->{pproc}->restart();
  $bk->{pproc}->set_module(Shb7::Path::module());

  # first step
  for(@bfile) {
    $bk->log_fpath($ARG->{src});
    $bk->fbuild($ARG);
  };

  # ^with all files handled, now go again
  Log->step("running second MAM pass");
  $bk->{pproc}->set_pass(1);
  for(@bfile) {
    $bk->log_fpath($ARG->{obj});
    $bk->fbuild($ARG);
  };
  return (0);
};


# ---   *   ---   *   ---
# Perl "building"
#
# it's just a preprocessor step
# (see: MAM.pm)

sub fbuild {
  my ($bk,$sw,$bfile)=@_;
  my $pproc=$bk->{pproc};

  # first pass?
  my ($dst,$src);
  if($pproc->{pass} == 0) {
    # write from src to object
    ($dst,$src)=($bfile->{obj},$bfile->{src});

  # ^final pass?
  } else {
    # write from object to library path
    $src=$bfile->{obj};
    $dst=Shb7::Path::fmirror(
      $bfile->{src},
      ext   => 'pm',
      rel   => 0,
      reloc => [
        Shb7::Path::module_re(),
        Shb7::Path::libdirp(),
      ],
    );
say "avto::bk::MAM -> $dst";
exit;
  };

  # process file and give
  owc($dst,$pproc->run($dst,$src));
  return 0;
};


# ---   *   ---   *   ---
# writes *.pmd dependency files for MAM

sub depsmake {
  my ($bk,$sw,@bfile)=@_;
  return if ! @bfile;

  # notify we're here
  Log->step('rebuilding dependencies');

  # run through the files...
  for(@bfile) {
    my ($dst,$src)=($ARG->{dep},$ARG->{obj});

    # put filename
    $bk->log_fpath($src);

    # we *execute* the file in a "sandbox"
    # to get the dependency list (!!!)
    #
    # its the same process as a syntax check
    # (like `perl -c`), but it doesn't require
    # forking, so its incredibly faster
    my @dep=AR::run('Chk::Deps',$src,orc($src));

    # drop first elem as its just the
    # name of the file itself
    shift @dep;

    # save the dependency list to a *.pmd file
    my $body=join "\n",@dep;
    owc($dst,$body);
  };
  return;
};


# ---   *   ---   *   ---
1; # ret
