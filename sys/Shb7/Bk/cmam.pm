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
  # notify we're here
  CMAM::restart();
  Log->ex('MAM',"C preprocessor:");

  # walk [fname => src]
  for(@bfile) {
    my ($fname,$head,$body,$perl)=
      @{(CMAM::run($ARG->{src}))[0]};

    # generating header?
    my $fhead=null;
    if(! is_null($head)) {
      $fhead=$fname;
      extwap($fhead,'h');

      throw "Cannot generate C header for "
      .     "'$fname': destination is source!"

      if $fhead eq $fname;

      owc $fhead,$head;
    };

    # generating source?
    if(! is_null($body)) {
      my $fbody=Shb7::Path::obj_from_src(
        $fname,
        ext=>'c',
        rel=>0
      );

      throw "Cannot generate C source for "
      .     "'$fname': destination is source!"

      if $fbody eq $fname;

      # include generated header ;>
      if(! is_null($fhead)) {
        $body="#include \"$fhead\"\n$body";
      };

      reqdir(dirof($fbody));
      owc $fbody,$body;

      # tell gcc to compile the generated source
      # instead of the actual file
      $ARG->{src}=$fbody;

    } else {
      undef $ARG;
    };

    # generating perl package?
    if(! is_null($perl)) {
      my $fperl=Shb7::Path::fmirror(
        $fname,
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

      throw "Cannot generate perl package for "
      .     "'$fname': destination is source!"

      if $fperl eq $fname;

      reqdir(dirof($fperl));
      owc $fperl,$perl;
    };
  };

  # notify we're leaving ;>
  Log->ex('GNU','C compiler:');
  filter(\@bfile);
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
