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
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::cmam;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Cwd qw(abs_path);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);

  use Arstd::Array qw(filter);
  use Arstd::Bin qw(orc owc moo);
  use Arstd::Path qw(reqdir dirof extwap);
  use Arstd::throw;

  use Shb7::Path qw(relto_root);
  use Ftype::Text::C;

  use Log;
  use parent 'Shb7::Bk';

  use lib "$ENV{ARPATH}/lib/";
  use CMAM;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub oflg {return qw(
  -O2
  -fpermissive
  -w
  -ftree-vectorize
  -fno-unwind-tables
  -fno-eliminate-unused-debug-symbols
  -fno-asynchronous-unwind-tables
  -ffast-math
  -fsingle-precision-constant
  -fno-ident
  -fPIC
)};

sub lflg {return qw(
  -fpermissive
  -w
  -flto
  -ffunction-sections
  -fdata-sections
), (
  '-Wl,--gc-sections',
  '-Wl,-fuse-ld=bfd',
)};

sub flatflg {return qw(
  -fpermissive
  -w
  -flto
  -ffunction-sections
  -fdata-sections
  -no-pie
  -nostdlib
), (
  '-Wl,--gc-sections',
  '-Wl,-fuse-ld=bfd',
  '-Wl,--relax,-d',
  '-Wl,--entry=_start',
)};


# ---   *   ---   *   ---
# rebuild chk

sub fupdated($self,$bfile,%O) {
  # a CMAM update means all files need to
  # be recompiled
  my @cmam=CMAM::outdeps();
  return 1 if int grep {
    moo($bfile->{obj},$ARG);

  } @cmam;

  # else perform a standard dependency check
  return $self->chkfdeps($bfile,%O);
};


# ---   *   ---   *   ---
# get file dependencies

sub fdeps($self,$bfile) {
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
    @out=$self->depstr_to_array($body);

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
# get variant of arch flag

sub target($tgt) {
  my $out;
  if($tgt eq Shb7::Bk::target_arch('x64')) {
    $out='-m64';

  } elsif($tgt eq Shb7::Bk::target_arch('x86')) {
    $out='-m32';
  };

  return $out;
};


# ---   *   ---   *   ---
# get variant of entry flag

sub entry($name) {return "-Wl,--entry=$name"};


# ---   *   ---   *   ---
# get array of build files, but sorted
# by dependencies

sub bfiles($self) {
  my @bfile=@{$self->{file}};
  return @bfile if exists $self->{sorted};

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
  $self->{file}   = [@out];
  $self->{sorted} = 1;
  return @out;
};

# ---   *   ---   *   ---
# preproc step

sub on_build($self,$bld,@bfile) {
  # first off, check that there is need
  # for regenerating intermediate files
  @bfile=map {
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
    || moo($fperl,$ARG->{src})) {
      $ARG->{-cmamp}={
        head=>$fhead,
        body=>$fbody,
        perl=>$fperl,
      };
      $ARG;

    } else {()};

  } @bfile;

  # ^early exit if nothing to do
  return () if ! @bfile;


  # ^else notify we're here
  Log->ex('MAM',"C preprocessor:");

  # walk [fname => src]
  for(@bfile) {
    # fetch the destination paths we
    # calculated earlier
    my $fname = $ARG->{src};
    my $dst   = $ARG->{-cmamp};

    $self->log_fpath($ARG->{src});

    my ($ar)=CMAM::run($fname);
    my ($head,$body,$perl)=@$ar;

    # fairly redundant to run these checks, but
    # it would massively suck to overwrite the
    # source if some accident happens...
    throw "Cannot generate C header for "
    .     "'$fname': destination is source!"

    if $fname eq $dst->{head};

    throw "Cannot generate C source for "
    .     "'$fname': destination is source!"

    if $fname eq $dst->{body};

    throw "Cannot generate perl package for "
    .     "'$fname': destination is source!"

    if $fname eq $dst->{perl};


    # include generated header
    my $skip=is_null($body);
    $body="#include \"$dst->{head}\"\n$body";

    # *now* update the files
    #
    # we do this no matter what simply because
    # the build will check that all three exist
    reqdir(dirof($ARG)) for values %$dst;
    owc $dst->{head},$head;
    owc $dst->{body},$body;
    owc $dst->{perl},$perl;

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

sub fbuild($self,$bfile,$bld) {
  # conditionally use octopus
  my $cpp=Ftype::Text::C->is_cpp($bfile->{src});
  my $up=($cpp)
    ? '-lstdc++'
    : null
    ;

  # clear existing
  $bfile->prebuild();

  # cstruc cmd
  my @call=(
    ($cpp) ? q[g++] : q[gcc] ,

    '-MMD',
    target($bld->{tgt}),

    (map {"-D$ARG"} @{$bld->{def}}),

    @{$bld->{flag}},
    oflg(),

    @{$bld->{inc}},
    $up,

    "-Wa,-a=$bfile->{asm}",
    -c => $bfile->{src},
    -o => $bfile->{obj},

    @{$bld->{lib}},
  );

  # ^cleanup and invoke
  filter(\@call);
  system {$call[0]} @call;

  # ^give on success
  return int(defined is_file($bfile->{obj}));
};


# ---   *   ---   *   ---
1; # ret
