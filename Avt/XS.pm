#!/usr/bin/perl
# ---   *   ---   *   ---
# XS
# Uses ExtUtils to make XS
# ... yep, we ain't writing it by hand ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Avt::XS;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(getcwd);
  use English qw($ARG);
  use Storable qw(store);
  use XSLoader;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);

  use Arstd::String qw(strip);
  use Arstd::Array qw(dupop);
  use Arstd::Bin qw(moo orc owc);
  use Arstd::Path qw(
    to_pkg
    from_pkg
    extcl
    extwap
    basef
    based
    dirof
    parof
    reqdir
  );
  use Arstd::throw;
  use Arstd::fatdump;

  use Shb7::Path qw(
    dirp
    include
    modp
    shared_libp
    static_libp
    libdirp
    ctrashp
    relto_root
    relto_mod
  );
  use Shb7::Find qw(ffind wfind);
  use Shb7::Bk::cmam;

  use lib "$ENV{ARPATH}/lib/";
  use AR;
  use Avt::XS::Type;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# compiles XS from shwl

sub build($shwl,$bld,$name,%O) {
  # defaults
  $O{-f} //= 0;

  # check whether we can skip compilation
  my $dst = shared_libp($name);
  my $ok  = 0;
  for my $obj(@{$shwl->{obj}}) {
    $ok+=int(moo($dst,$obj));
  };
  return if ! $ok;

  # make path if need
  my $trash=ctrashp() . '/.XS';
  reqdir($trash);

  # generate XS code with wrappers for
  # all exported symbols
  xsgen($trash,$name,$shwl);

  # get a string with the compiler flags we use
  my $ccflag=join ' ',(
    @{$bld->{flag}},
    Shb7::Bk::cmam::oflg(),
  );

  # add dependencies to lib path
  push @{$bld->{lib}},@{$shwl->{dep}},"-l$name";
  dupop($bld->{lib});

  # generate and run makefile
  my $makefile=makegen(
    $trash,
    NAME      => $name,
    LIBS      => $bld->libline(),
    INC       => $bld->incline(),
    CCFLAGS   => $ccflag,
    MYEXTLIB  => static_libp($name),
    TYPEMAPS  => [Avt::XS::Type->table()],
  );
  my $old=getcwd();
  chdir $trash;
  `perl $makefile && make`;
  chdir $old;

  # ^find the generated *.so
  my $out="$trash/blib/arch/auto/$name/$name.so";
  throw "'$out'\nXS build fail" if ! -f $out;

  # we move the *.so to where XSLoader can find it
  rename $out,$dst;
  return;
};


# ---   *   ---   *   ---
# XS code is not so bad, actually ;>
#
# this F takes the shwl and outputs
# wrappers for all of it's symbols

sub xsgen($path,$pkg,$shwl) {
  my $body=null;

  # walk shwl->src->[symbols]
  for my $src(@{$shwl->{src}}) {
  for my $sym(@$src) {
    my $name = $sym->{name};
    my $type = (! is_null($sym->{type}))
      ? $sym->{type}
      : 'void'
      ;

    # generate signature
    my (@argname,@argtype);
    for(@{$sym->{args}}) {
      if(! is_null($ARG->{type})) {
        push @argname,"$ARG->{name}";
        push @argtype,"$ARG->{type} $ARG->{name}";

      } else {
        push @argtype,'void';
      };
    };
    my $sig="$name(" . join(',',@argname) . ')';

    # add definition for this symbol
    $body .= join("\n",
      $type,
      $sig,
      (map {"    $ARG"} @argtype),

      "  CODE:",
      ($type ne 'void')
        ? ("    RETVAL = $sig;",
           "  OUTPUT:",
           "    RETVAL")

        : ("    $sig;")
        ,
      "\n",
    );
  }};

  # the 'sign' specifier is a peso thing,
  # the actual typename would be sign_[type]
  my $sign_re=qr{\bsign +};
  $body=~ s[$sign_re][sign_]smg;

  # set the destination package that the
  # xsubs will be added to
  my $fname=$pkg;
  from_pkg($fname);
  extwap($fname,'xs');

  # write *.xs file and give
  reqdir(dirof("$path/$fname"));
  owc("$path/$fname",join("\n",
    $shwl->{hed},
    "MODULE = $pkg PACKAGE = $pkg",
    "PROTOTYPES: DISABLE",
    "$body",
  ));
  return;
};


# ---   *   ---   *   ---
# output makefile

sub makegen($path,%O) {
  my $out    = 'Makefile.PL';
  my $config = fatdump \{%O},mute=>1;
  my $body   = join(";\n",
    q[use ExtUtils::MakeMaker],
    'WriteMakefile(%{' . $config . '})',
    q[sub MY::makefile { '' }],
  );
  owc("$path/$out",$body);
  return $out;
};


# ---   *   ---   *   ---
# fetches the *.so

sub load($name) {
  XSLoader::load($name,v0.00);
  return;
};


# ---   *   ---   *   ---
# collects symbol data generated
# by CMAM for use by an XS module

sub mkshwl($mod,$dst,$deps,@fname) {
  # early exit if nothing to do
  return if ! @fname;

  # setup search path
  include(dirp($mod));

  # expand file list from names
  my @file=map {
    grep {$ARG} ($ARG=~ qr{\%})
      ? wfind($ARG)
      : ffind($ARG)
      ;
  } @fname;


  # nit table
  my $shwl={
    dep   => $deps,
    fswat => $mod,
    obj   => [],
    src   => [],
    hed   => join("\n",
      q[#include "EXTERN.h"],
      q[#include "perl.h"],
      q[#include "XSUB.h"],
      null,
    ),
  };

  # ^iter through expanded list to fill it out
  for(@file) {
    my $fcpy=$ARG;
    relto_mod($fcpy);
    extwap($fcpy,'pm');
    to_pkg($fcpy);

    # skip if no symbols exported for this file
    AR::reload($fcpy);
    next if ! $fcpy->can('XSHED');

    # record symbol data for each object file
    my $o=Shb7::Path::obj_from_src($ARG);
    relto_root($o);

    push @{$shwl->{obj}},$o;
    push @{$shwl->{src}},$fcpy->XSHED();

    # now include the header for it ;>
    my $h=$ARG;
    extwap($h,'h');
    $shwl->{hed} .= "#include \"$h\"\n";
  };

  # dump table to disk
  store($shwl,$dst) or throw $dst;
  return $shwl;
};


# ---   *   ---   *   ---
1; # ret
