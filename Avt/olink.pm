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
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::olink;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Cwd qw(abs_path);
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use lib $ENV{'ARPATH'}.'/lib/';

  use Style;
  use Cli;

  use Arstd::Path;
  use Arstd::Array;
  use Arstd::WLog;
  use Arstd::PM;
  use Arstd::IO;

# ---   *   ---   *   ---
# info

  our $VERSION = v1.00.6;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $FEND=>[

    'Avt::flatten' => [qw(s asm inc)],

    'Avt::CRun'    => [qw(c cpp)],
    'Avt::Droid'   => [qw(kt)],

  ];

  Readonly my $FEND_KEYS=>[
    array_keys($FEND)

  ];

# ---   *   ---   *   ---
# in a nutshell

sub crux(@cmd) {

  Arstd::WLog->genesis();
  $WLog->ex('olink');


  my ($m,$files) = parse_args(@cmd);

  my $bld        = compile($m,$files);
  my $obj        = xlink($bld);

  run($m,$obj);


  $WLog->step('done');

};

# ---   *   ---   *   ---
# tell this program what to do!

sub parse_args(@cmd) {

  # define options
  my $m=Cli->new(

    # standard filesearch opts
    @{$Cli::Fstruct::ATTRS},

    # ^olink specific
    {id=>'libs',short=>'-l',argc=>1},
    {id=>'incl',short=>'-I',argc=>1},
    {id=>'out',short=>'-o',argc=>1},

    {id=>'debug',short=>'-g',argc=>0},
    {id=>'-pg',short=>'-pg',argc=>0},
    {id=>'run',short=>'-r',argc=>1},
    {id=>'runrm',short=>'-xr',argc=>1},

  );


  # run file search
  my @files=Cli::Fstruct::proto_search(
    $m,@cmd

  );


  # nullout include and lib paths
  for my $v($m->{incl},$m->{libs}) {
    $v=$NULLSTR if $v eq $NULL

  };

  # generate default output path if none passed
  $m->{out}=($m->{out} eq $NULL)
    ? dirof($files[0]) .'/'. nxbasef($files[0])
    : $m->{out}
    ;


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
  my $by_fend = {};

  # get filtered file list
  my $by_ext=sort_by_ext($files);


  # array as hash
  my $idex   = 0;
  my @values = array_values($FEND);

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


  } @$FEND_KEYS;


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

  } @$FEND_KEYS;


  # invoke frontend for each compiler type
  my @bld=map {

    # include builder class
    my $class = $ARG;
    my $flist = $by_fend->{$class};

    cload($class);

    # ^cstruc builder ice
    my $exe = $class->new(

      name  => $m->{out},

      libs  => $m->{libs},
      incl  => $m->{incl},

      debug => $m->{debug} ne $NULL,
      files => $flist,

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

sub throw_bad_files($files) {

  map {

    $WLog->step(
      "unrecognized FF *.$ARG",

    );

  } map {extof($ARG)} @$files;


  $WLog->err('aborted',from=>'olink');
  exit -1;

};

# ---   *   ---   *   ---
# selects linking method

sub xlink($bld) {

  # first obj assumed main
  my $obj=$bld->[-1];

  # ^collapse all objects into one!
  @{$obj->{files}}=map {
    @{$ARG->{files}}

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

  if($m->{run} ne $NULL) {
    $rargs=$m->{run};

  } elsif($m->{runrm} ne $NULL) {
    $rargs = $m->{runrm};
    $rdel  = 1;

  };

  # ^do the twist
  if(defined $rargs) {

    $WLog->ex($obj->{bld}->{name});

    $obj->run(split $COMMA_RE,$rargs);
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

  return IMP(

    $class,

    \&ON_USE,
    \&ON_EXE,

    @req

  );

};

# ---   *   ---   *   ---
# ^imported as exec via arperl

sub ON_EXE($class,@cmd) {
  crux(grep {defined $ARG} @cmd);

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
