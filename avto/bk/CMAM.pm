#!/usr/bin/perl
# ---   *   ---   *   ---
# BK CMAM
# Wrappers for C builds
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::bk::CMAM;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Cwd qw(abs_path);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);

  use Arstd::String qw(gsplit);
  use Arstd::Array qw(filter);
  use Arstd::Bin qw(orc owc moo);
  use Arstd::Path qw(reqdir dirof extwap);
  use Arstd::throw;

  use Shb7::Path qw(relto_root);
  use Ftype::Text::C;

  use Log;

  use lib "$ENV{ARPATH}/lib/";
  use AR;
  use CMAM;
  use parent 'avto::bk';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.2a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub linkable {return 1};


# ---   *   ---   *   ---
# cstruc

sub new {
  my ($class,$px,%O)=@_;
  my $bk=avto::bk::new($class,$px,%O);

  return $bk;
};


# ---   *   ---   *   ---
# rebuild chk

sub fupdated {
  my ($bk,$bfile)=@_;

  # a CMAM update means all files need to
  # be recompiled
  my @cmam=CMAM::outdeps();
  return 1 if int grep {
    moo($bfile->{obj},$ARG);

  } @cmam;

  # else perform a standard dependency check
  return avto::bk::fupdated($bk,$bfile);
};


# ---   *   ---   *   ---
# get file dependencies

sub fdeps {
  my ($bk,$bfile)=@_;
  my @out=($bfile->{src});

  # read file if it exists
  my $bslash_re=qr{\\\n};
  my $nspace_re=qr{\s+};
  my $colon_re=qr{^.*\: };
  if(is_file($bfile->{dep})) {
    my $body=orc($bfile->{dep});

    # sanitize
    $body=~ s[$colon_re][];
    $body=~ s[$bslash_re][]g;
    $body=~ s[$nspace_re][,]g;

    # make array from gcc depsfile
    @out=gsplit($body,qr{\s*,\s*});

    # drop first file, which is always the source
    # we run that check elsewhere
    shift @out;

    # drop second file if it's the header
    # we generate those, so also not needed
    my $hed=$bfile->{src};
    extwap($hed,'h');
    shift @out if @out && $out[0] eq $hed;
  };

  return @out;
};


# ---   *   ---   *   ---
# get array of build files, but sorted
# by dependencies

sub bfiles {
  my ($bk)=@_;

  # stop if already sorted
  my @bfile=@{$bk->{file}};
  return @bfile if exists $bk->{sorted};

  # get sorted list first
  my @src    = map {$ARG->{src}} @bfile;
  my @sorted = CMAM::depsort(
    Shb7::Path::module(),
    @src,
  );

  # ^now map sorted file names to bfile objects
  my @out=();
  for my $fname(@sorted) {
    push @out,grep {
      abs_path($ARG->{src}) eq $fname

    } @bfile;
  };

  # mark file list as already sorted
  $bk->{file}   = [@out];
  $bk->{sorted} = 1;
  return @out;
};


# ---   *   ---   *   ---
# preproc step

sub on_build {
  my ($bk,$sw)=@_;

  # first off, check that there is need
  # for regenerating intermediate files
  my @bfile=map {
    # get path to generated header...
    my $fhead=$ARG->{src};
    extwap($fhead,'h');

    # ^then generated source...
    my $fbody=Shb7::Path::obj_from_src(
      $ARG->{src},
      ext=>'c',
      rel=>0
    );

    # ^and then perl module
    my $fperl=Shb7::Path::fmirror(
      $ARG->{src},
      ext   => 'pm',
      rel   => 0,
      reloc => [
        Shb7::Path::root_re(),
        null(),
      ],
    );

    my $re='^/?' . Shb7::Path::module() . '/+';
       $re=qr{$re};

    $fperl=~ s[$re][];
    $fperl=Shb7::Path::lib()->[0] ."/$fperl";


    # ^ if either file needs regeneration,
    #   *then* we run the preprocessor
    if(moo($fhead,$ARG->{src})
    || moo($fbody,$ARG->{src})
    || moo($fperl,$ARG->{src})

    # ^ also consider the object, obviously ;>
    || moo($ARG->{obj},$ARG->{src})) {
      $ARG->{-cmamp}={
        head=>$fhead,
        body=>$fbody,
        perl=>$fperl,
      };
      $ARG;

    } else {()};

  } $bk->updated();

  # ^early exit if nothing to do
  return () if! @bfile;


  # ^else notify we're here
  Log->ex('MAM',"C preprocessor:");

  # walk [fname => src]
  for(@bfile) {
    # fetch the destination paths we
    # calculated earlier
    my $fname = $ARG->{src};
    my $dst   = $ARG->{-cmamp};

    $bk->log_fpath($ARG->{src});

    my ($ar)=CMAM::run($fname);
    my ($head,$body,$perl)=@$ar;

    # fairly redundant to run these checks, but
    # it would massively suck to overwrite the
    # source if some accident happens...
    throw "Cannot generate C header for "
    .     "'$fname': destination is source!"

    if    $fname eq $dst->{head};

    throw "Cannot generate C source for "
    .     "'$fname': destination is source!"

    if    $fname eq $dst->{body};

    throw "Cannot generate perl package for "
    .     "'$fname': destination is source!"

    if    $fname eq $dst->{perl};


    # include generated header
    my $skip=is_null($body);
    $body="#include \"$dst->{head}\"\n$body";

    # *now* update the files
    #
    # we do this no matter what simply because
    # the build will check that all three exist
    reqdir(dirof($ARG)) for values %$dst;
    owc($dst->{head},$head);
    owc($dst->{body},$body);
    owc($dst->{perl},$perl);

    # however, we do skip compiling files that
    # output a blank source ;>
    if($skip) {
      undef $ARG;

    # ^ tell gcc to compile the generated source
    #   instead of the actual file
    } else {
      $ARG->{src}=$dst->{body};
    };
  };

  # since we undefine files that need to be
  # skipped by the compiler, we make sure
  # to remove blank entries from the list
  filter(\@bfile,sub {
      is_null($_[0])
  ||! int(%{$_[0]})
  });

  # notify we're leaving ;>
  Log->ex('GNU','C compiler:') if @bfile;

  # give filtered file list for compiler
  return @bfile;
};


# ---   *   ---   *   ---
# C-style object file boiler

sub fbuild {
  my ($bk,$sw,$bfile)=@_;

  # conditionally use octopus
  my $cpp = Ftype::Text::C->is_cpp($bfile->{src});
  my @up  = ($cpp ? '-lstdc++' : ());

  # cstruc cmd
  my @call=(
    ($cpp ? q[g++] : q[gcc]),

    '-MMD',

    @{$sw->{arch}},
    @{$sw->{def}},
    @{$sw->{obc}},
    @{$sw->{inc}},

    -c => $bfile->{src},
    -o => $bfile->{obj},

    "-Wa,-a=$bfile->{asm}",

    @{$sw->{lib}},
    @up,
  );

  # ^cleanup and invoke
  filter(\@call);
  system {$call[0]} @call;

  # ^give on success
  return is_file($bfile->{obj});
};


# ---   *   ---   *   ---
1; # ret
