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
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::front;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Cwd qw(abs_path);
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::String;
  use Arstd::Path;
  use Arstd::Array;
  use Arstd::PM;

  use Shb7::Build;
  use Emit::Std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
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

  $O{files}   //= [];
  $O{gens}    //= [];

  $O{incl}    //= [];
  $O{libs}    //= [];
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

  } @{$O{gens}};

  # ^cat generated files and includes
  my %lists=$class->mklists(
    $O{incl},$O{libs},$O{libpath}

  );

  push @{$O{files}},array_keys(\@gens);
  push @{$lists{incl}},array_values(\@gens);

  array_filter($O{files});


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

  # make ice
  my $self=bless {

    bk    => $bk,
    bld   => $bld,

    files => $O{files},

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# ^compiles with passed settings

sub compile($self) {

  my $blt=0;

  for my $f(@{$self->{files}}) {
    $f    = $self->{bk}->push_src(abs_path($f));
    $blt += $f->update($self->{bld});

  };

  return $blt;

};

# ---   *   ---   *   ---
# ^selfex

sub link($self) {
  $self->{bld}->push_files(@{$self->{files}});
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
  my @incl=$class->incl_deduce(@$heds);

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

sub mklists($class,$incl,$libs,$libpath) {


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


  } ($incl,$libs,$libpath);


  # ^give hashref with processed data
  return (
    incl    => $incl,
    libs    => $libs,
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
    @pre,
    map {$ARG="$ch$ARG"} deref_clist($src)

  ];

};

# ---   *   ---   *   ---
# deduce include directories
# from the header path

sub incl_deduce($class,@inc) {

  my @out=map {

    ($NULLSTR,based($ARG))[
      int($ARG=~ $FSLASH_RE)

    ]

  } @inc;

  return @out;

};

# ---   *   ---   *   ---
1; # ret
