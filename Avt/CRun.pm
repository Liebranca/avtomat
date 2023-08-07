#!/usr/bin/perl
# ---   *   ---   *   ---
# CRUN
# Generates C files and
# links them; exec optional
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::CRun;

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

  use Shb7::Bk::gcc;
  use Shb7::Build;

  use Emit::Std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $INC_FILTER=>qr{^" | \.h(?:pp)?"$}x;

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{name}   //= './out';
  $O{debug}  //= 0;

  $O{files}  //= [];
  $O{gens}   //= [];

  $O{incl}   //= [];
  $O{libs}   //= [];

  # determine author/version
  # for generators
  my $mod  = caller;
  my $info = [
    Emit::Std::get_version($mod),
    Emit::Std::get_author($mod),

  ];

  # run generators
  my @gens=map {
    $class->exgen($info,$ARG)

  } @{$O{gens}};

  # ^cat generated files and includes
  my %lists=$class->mklists(
    $O{incl},$O{libs}

  );

  push @{$O{files}},array_keys(\@gens);
  push @{$lists{incl}},array_values(\@gens);

  array_filter($O{files});

  # make builder ice
  my $bk  = Shb7::Bk::gcc->nit();
  my $bld = Shb7::Build->nit(

    name  => $O{out},
    debug => $O{debug},

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
# ^compile, link and run

sub go($self) {

  $self->compile();
  $self->link();

  return `$self->{bld}->{name}`;

};

# ---   *   ---   *   ---
# wraps over code generator execution

sub exgen($class,$info,$O) {

  # defaults
  $O->{lang}   //= 'C';
  $O->{args}   //= [];
  $O->{syshed} //= [];
  $O->{usrhed} //= [];

  # ^cat user and system headers
  my $heds=$class->cathed(
    $O->{syshed},$O->{usrhed}

  );

  my ($version,$author)=@$info;
  my @incl=$class->incl_deduce(@$heds);

  Emit::Std::outf(

    $O->{lang},
    $O->{fname},

    include    => $heds,

    body       => $O->{body},
    args       => $O->{args},

    add_guards => 1,

    version    => $version,
    author     => $author,

  );

  return $O->{fname} => \@incl;

};

# ---   *   ---   *   ---
# cat user and system headers
# wraps them in "quotes" and
# <braces>, respectively

sub cathed($class,$sys,$usr) {

  my @sys=map {"<$ARG>"} @$sys;
  my @usr=map {"\"$ARG\""} @$usr;

  return [@sys,@usr];

};

# ---   *   ---   *   ---
# get arrayref of includes
# from either a comma-separated
# string or an arrayref

sub inc_list($class,$src) {

  return [q[-I./], map {
    $ARG=q[-I].$ARG

  } deref_clist($src)];

};

# ---   *   ---   *   ---
# ^libs

sub lib_list($class,$src) {

  return [map {
    $ARG=q[-l].$ARG

  } deref_clist($src)];

};

# ---   *   ---   *   ---
# deduce include directories
# from the header path
#
# <system-headers> are
# excluded from out

sub incl_deduce($class,@inc) {

  my @out=map {
    ($NULLSTR,based($ARG))[int($ARG=~ $FSLASH_RE)]

  } grep {$ARG=~ $INC_FILTER} @inc;

  map {
    $ARG=~ s[$INC_FILTER][]sxmg

  } @out;

  array_filter(\@out);
  return @out;

};

# ---   *   ---   *   ---
# makes lib/include lists

sub mklists($class,$incl,$libs) {

  array_filter($incl) if is_arrayref($incl);
  array_filter($libs) if is_arrayref($libs);

  $incl=$class->inc_list($incl);
  $libs=$class->lib_list($libs);

  array_dupop($incl);
  array_dupop($libs);

  return (
    incl => $incl,
    libs => $libs,

  );

};

# ---   *   ---   *   ---
1; # ret
