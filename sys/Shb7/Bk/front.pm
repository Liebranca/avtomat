#!/usr/bin/perl
# ---   *   ---   *   ---
# BK FRONT
# Front to back!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::front;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);
  use English;

  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Chk qw(is_arrayref);

  use Arstd::String qw(deref_clist);
  use Arstd::Path qw(based);
  use Arstd::Array qw(
    array_keys
    array_values
    array_filter
    array_dupop

  );

  use Arstd::PM qw(cload);

  use Shb7::Build;
  use Emit::Std;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{name}    //= './out';
  $O{debug}   //= 0;
  $O{clean}   //= 0;
  $O{entry}   //= '_start';
  $O{bk}      //= 'flat';
  $O{lang}    //= 'fasm';
  $O{linking} //= 'flat';
  $O{pproc}   //= undef;

  $O{file}    //= [];
  $O{gen}     //= [];

  $O{inc}     //= [];
  $O{lib}     //= [];
  $O{libpath} //= [];


  # determine author/version
  # for generators
  my $mod  = caller;
  my $info = [
    Emit::Std::get_version($mod),
    Emit::Std::get_author($mod),

  ];

  # run generators
  my @gens=map {
    $ARG->{lang} //= $O{lang};
    $class->exgen($info,$ARG);

  } @{$O{gen}};

  # ^cat generated files and includes
  my %lists=$class->mklists(
    $O{inc},
    $O{lib},
    $O{libpath}

  );

  push @{$O{file}},array_keys(\@gens);
  push @{$lists{inc}},array_values(\@gens);

  array_filter($O{file});


  # make builder ice
  my $bkn=q[Shb7::Bk::].$O{bk};
  cload($bkn);

  my $bk  = $bkn->new(pproc=>$O{pproc});
  my $bld = Shb7::Build->new(
    name    => $O{name},
    debug   => $O{debug},
    clean   => $O{clean},
    linking => $O{linking},
    entry   => $O{entry},

    lang    => $O{lang},

    %lists,

  );


  # make ice and give
  my $self=bless {
    bk   => $bk,
    bld  => $bld,
    file => $O{file},

  },$class;

  return $self;

};


# ---   *   ---   *   ---
# ^compiles with passed settings

sub compile($self) {
  return int grep {
    $ARG=$self->{bk}->push_src(abs_path($ARG));
    $ARG->update($self->{bld});

  } @{$self->{file}};

};


# ---   *   ---   *   ---
# ^selfex

sub link($self) {
  $self->{bld}->push_files(@{$self->{file}});
  $self->{bld}->olink();

};


# ---   *   ---   *   ---
# variants of execution

sub captrun($self,@args) {
  return `$self->{bld}->{name} @args`;

};

sub sysrun($self,@args) {
  return system {$self->{bld}->{name}} @args;

};

sub xrun($self,@args) {
  return exec {$self->{bld}->{name}} @args;

};


# ---   *   ---   *   ---
# ^crux

sub run($self,@args) {
  state $invalid=qr{(?:mode)};
  my %O=@args;

  # defaults
  $O{_xmode} //= 'sys';

  # ^select F
  my $fn="$O{_xmode}run";

  # ^discard mode
  delete $O{_xmode};


  # rebuild args
  my $i=0;
  @args=grep {defined $ARG} map {

    # get [key=>value]
    my ($x,$y)=@args[$i*2+0..$i*2+1];

    # remove args for $this
    $x=undef if defined $x && $x=~ $invalid;
    $y=undef if defined $y && $y=~ $invalid;

    # ^go next
    $i++;
    $x,$y;

  } array_keys(\@args);

  # ^invoke
  $self->$fn(@args);
  return;

};


# ---   *   ---   *   ---
# ^compile, link and run

sub go($self,@args) {
  $self->compile();
  $self->link();

  return $self->run(@args);

};


# ---   *   ---   *   ---
# remove output file

sub rmout($self) {
  unlink $self->{bld}->{name};

};


# ---   *   ---   *   ---
# wraps over code generator execution

sub exgen($class,$info,$O) {

  # defaults
  $O->{syshed} //= [];
  $O->{usrhed} //= [];

  # ^cat user and system headers
  my $heds=$class->cathed(
    $O->{syshed},
    $O->{usrhed}

  );

  my ($version,$author)=@$info;
  my @incl=$class->inc_deduce(@$heds);

  array_filter(\@incl);

  Emit::Std::outf(
    $O->{lang},
    $O->{fname},

    inc     => $heds,
    body    => $O->{body},

    guards  => 1,

    version => $version,
    author  => $author,

  );


  return $O->{fname} => \@incl;

};


# ---   *   ---   *   ---
# wrap header names in quotes

sub cathed($class,$sys,$usr) {
  return [map {"\"$ARG\""} @$usr,@$sys];

};


# ---   *   ---   *   ---
# makes lib/include lists

sub mklists($class,$inc,$lib,$libpath) {

  # ordered data for processing each arg
  my @proc=([-I=>'-I./'],[-l=>()],[-L=>()]);

  # ^walk
  map {

    # input is array or string?
    array_filter($ARG) if is_arrayref($ARG);

    # process accto data type
    my (@cmd)=@{(shift @proc)};
    $ARG=$class->x_list($ARG,@cmd);

    # remove duplicates!
    array_dupop($ARG);


  } ($inc,$lib,$libpath);


  # ^give hashref with processed data
  return (
    inc     => $inc,
    lib     => $lib,
    libpath => $libpath,

  );

};


# ---   *   ---   *   ---
# prototype:
#
# get arrayref from either
# a comma-separated string
# or an arrayref

sub x_list($class,$src,$ch,@pre) {
  return [
    @pre,map {$ARG="$ch$ARG"} deref_clist($src)

  ];

};


# ---   *   ---   *   ---
# deduce include directories
# from the header path

sub inc_deduce($class,@inc) {
  return map {
    (null,based($ARG))[
      int($ARG=~ $FSLASH_RE)

    ]

  } @inc;

};


# ---   *   ---   *   ---
1; # ret
