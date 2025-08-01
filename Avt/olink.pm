#!/usr/bin/perl
# ---   *   ---   *   ---
# OLINK
# Wraps over compiling and
# linking source files
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Avt::olink;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);
  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use lib "$ENV{ARPATH}/lib/";

  use Style;
  use Cli;

  use Arstd::Path qw(
    basef nxbasef dirof reqdir extof

  );

  use Arstd::Array qw(
    array_keys
    array_values
    array_filter

  );

  use Arstd::WLog;
  use Arstd::PM qw(cload IMP submerge);

  use Shb7::Path qw(walk moo);
  use Shb7::Bk::flat;
  use Shb7::Build;

  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v1.00.8';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

my $PKG=__PACKAGE__;
St::vconst {
  FEND=>[

    'Avt::flatten' => [qw(s asm inc)],

    'Avt::CRun'    => [qw(c cpp)],
    'Avt::Droid'   => [qw(kt)],

  ],

  FEND_KEYS=>sub {
    return [array_keys($_[0]->FEND)];

  },

};


# ---   *   ---   *   ---
# in a nutshell

sub crux(@cmd) {
  Arstd::WLog->genesis();
  $WLog->ex('olink');

  my ($m,$file)=parse_args(@cmd);

  if($m->{flat} ne null) {
    $WLog->step("rebuilding objects");

    my @obj=map {
      my $dir="$ARG/";

      croak "invalid directory '$dir'"
      if ! -d $dir;

      chdir $dir;
      reqdir "${dir}bld";

      my $tree=walk $dir;


      # get every *.asm file
      my @have=grep {
         ($ARG=~ qr{\.asm$})

      } $tree->get_file_list();

      # ^and corresponding *.o file for each
      my @out=map {
        my $fname=nxbasef $ARG;
        "${dir}bld/${fname}.o";

      } @have;


      # call fasm...
      map {
        my $fname=basef $ARG;
        $WLog->substep($fname);

        $fname=nxbasef $ARG;

        my $ok=Shb7::Bk::flat->asm(

          "$ARG ${dir}bld/${fname}.o",
          './.bkflat.tmp',

        );

        $WLog->err(
          'aborted',
          from => 'olink',
          lvl  => $AR_FATAL,

        ) if ! $ok;


        "${dir}bld/${fname}.o";


      # ^for every *.asm file that needs
      # ^to be rebuild
      } grep {
        my $fname=nxbasef $ARG;
        moo "${dir}bld/${fname}.o",$ARG;

      } @have;


      # give *.o files to link
      @out;


    } @$file;


    $WLog->step('linking objects');

    my $bld={name=>$m->{out}};
    Shb7::Build->defnit($bld);

    my @call=Shb7::Build::link_flat($bld,@obj);
    system {$call[0]} @call;


  } else {
    my $bld = compile($m,$file);
    my $obj = xlink($bld);

    run($m,$obj);

  };


  $WLog->step('done');
  return;

};


# ---   *   ---   *   ---
# tell this program what to do!

sub parse_args(@cmd) {

  # define options
  my $m=Cli->new(

    # standard filesearch opts
    @{Cli::Fstruct->ATTRS},

    # ^olink specific
    {id=>'lib',short=>'-l',argc=>1},
    {id=>'libpath',short=>'-L',argc=>1},
    {id=>'inc',short=>'-I',argc=>1},
    {id=>'out',short=>'-o',argc=>1},

    {id=>'require-C',short=>'-C',argc=>0},
    {id=>'flat',short=>'-f',argc=>1},

    {id=>'debug',short=>'-g',argc=>0},
    {id=>'clean',short=>'-c',argc=>0},

    {id=>'clean-debug',short=>'-gc',argc=>0},

    {id=>'-pg',short=>'-pg',argc=>0},
    {id=>'run',short=>'-r',argc=>1},
    {id=>'runrm',short=>'-xr',argc=>1},

  );


  # run file search
  my @files=Cli::Fstruct::proto_search($m,@cmd);

  # nullout include and lib paths
  map {$ARG //= null}
  ($m->{inc},$m->{lib},$m->{libpath});

  # generate default output path if none passed
  $m->{out}=($m->{out} eq null)
    ? dirof($files[0]) . '/' . nxbasef($files[0])
    : $m->{out}
    ;


  if($m->{'clean-debug'} ne null) {
    $m->{debug}=1;
    $m->{clean}=1;
    delete $m->{'clean-debug'};

  };

  return $m,\@files;

};


# ---   *   ---   *   ---
# separate files by extension

sub sort_by_ext($files) {
  my $by_ext={};

  map {
    my $ext=lc extof($ARG);
    $by_ext->{$ext} //= [];

    push @{$by_ext->{$ext}},$ARG;

  } @$files;


  return $by_ext;

};


# ---   *   ---   *   ---
# roll files together accto
# required frontend

sub sort_by_fend($files) {

  # output
  my $by_fend={};

  # get filtered file list
  my $by_ext=sort_by_ext($files);


  # array as hash
  my $idex   = 0;
  my @values = array_values($PKG->FEND);

  map {

    # ^map [files by ext]
    # ^to  [files by frontend]
    my $key=$ARG;
    my $ext=$values[$idex++];

    $by_fend->{$key}=[map {
      @{$by_ext->{$ARG}}
      if exists $by_ext->{$ARG}

    } @$ext];

    array_filter($by_fend->{$key});


  } @{$PKG->FEND_KEYS};


  return $by_fend;

};


# ---   *   ---   *   ---
# decides what to do with
# each file in the list

sub compile($m,$files) {

  # get filtered list of files
  my $by_fend = sort_by_fend($files);
  my @queue   = grep {
    @{$by_fend->{$ARG}}

  } @{$PKG->FEND_KEYS};


  # invoke frontend for each compiler type
  my @bld=map {

    # include builder class
    my $class = $ARG;
    my $flist = $by_fend->{$class};

    cload($class);

    # ^cstruc builder ice
    my $exe = $class->new(
      name    => $m->{out},

      lib     => $m->{lib},
      libpath => $m->{libpath},

      inc     => $m->{inc},

      debug   => $m->{debug} ne null,
      clean   => $m->{clean} ne null,
      file    => $flist,

      linking => ($m->{'require-C'} ne null)
        ? 1 : undef ,

    );


    # ^make objects and save
    $exe->compile();
    $exe;


  } @queue;


  throw_bad_files($files) if ! @bld;

  return \@bld;

};


# ---   *   ---   *   ---
# what you see when you forget
# to type the right extension...
#
# or when you type no extension at all!

sub throw_bad_files($file) {
  map {
    $WLog->step(
      "unrecognized FF *.$ARG",

    );

  } map {extof($ARG)} @$file;


  $WLog->err('aborted',from=>'olink');
  exit -1;

};


# ---   *   ---   *   ---
# selects linking method

sub xlink($bld) {

  # first obj assumed main
  my $obj=$bld->[-1];

  # ^collapse all objects into one!
  @{$obj->{file}}=map {
    @{$ARG->{file}}

  } (@$bld)[0..@$bld-1];


  # link and give main
  $obj->link();

  return $obj;

};


# ---   *   ---   *   ---
# execute application, optionally
# delete objects afterwards

sub run($m,$obj) {

  # ^get exec [args,flags]
  my $rargs = undef;
  my $rdel  = 0;

  map {
    $m->{$ARG}=null
    if ! defined $m->{$ARG}

  } qw(run runrm);


  if($m->{run} ne null) {
    $rargs=$m->{run};

  } elsif($m->{runrm} ne null) {
    $rargs = $m->{runrm};
    $rdel  = 1;

  };

  # ^do the twist
  if(defined $rargs) {
    $WLog->ex($obj->{bld}->{name});

    $obj->run(
      grep  {defined $ARG && length $ARG}
      split $COMMA_RE,$rargs

    );

    $obj->rmout() if $rdel;

  };


  return;

};


# ---   *   ---   *   ---
# AR/IMP:
#
# * runs crux with provided
#   input if run as executable
#
# * if imported as a module,
#   it aliases 'crux' to 'olink'
#   and adds it to the calling
#   module's namespace

sub import($class,@req) {
  return IMP($class,\&ON_USE,\&ON_EXE,@req);

};


# ---   *   ---   *   ---
# ^imported as exec via arperl

sub ON_EXE($class,@cmd) {
  return crux(grep {defined $ARG} @cmd);

};

# ---   *   ---   *   ---
# ^imported as module via use

sub ON_USE($class,$from,@nullarg) {
  *olink=*crux;

  submerge(
    ['olink'],

    main  => $from,
    subok => qr{^olink$},

  );


  return;

};


# ---   *   ---   *   ---
1; # ret
