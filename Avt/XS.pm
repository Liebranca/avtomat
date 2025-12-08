#!/usr/bin/perl
# ---   *   ---   *   ---
# XS
# Uses Inline::C to make XS
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
  use Arstd::Bin qw(orc);
  use Arstd::Path qw(
    to_pkg
    from_pkg
    extcl
    extwap
    basef
    based
    parof
    reqdir
  );
  use Arstd::throw;

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

  our $VERSION = 'v0.00.3a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# compiles XS stuff

sub build($shwl,$bld,$name,%O) {
  # get packages needed by build
  AR::load('Inline');

  # defaults
  $O{-f} //= 0,

  # make path if need
  my $trash=ctrashp() . '/_Inline';
  reqdir($trash);

  # get a string with the compiler flags we use
  my $ccflag=join ' ',(
    @{$bld->{flag}},
    Shb7::Bk::cmam::oflg(),
  );

  push @{$bld->{lib}},@{$shwl->{dep}},"-l$name";

  # we have to jump into the module directory
  # because Inline::C tries to find the current
  # script (./avto) to perform an unnecessary bit
  # of setup that crashes the build if said script
  # isnt found
  #
  # I cannot deactivate this 'feature'
  my $old=getcwd();
  chdir(modp());

  # make the call
  Inline->bind(C => $shwl->{hed} => (
    using     => 'ParseRegExp',

    name      => $name,
    directory => $trash,

    libs      => $bld->libline(),
    inc       => $bld->incline(),
    ccflags   => $ccflag,
    myextlib  => static_libp($name),

    typemaps  => Avt::XS::Type->table(),
    enable    => 'autowrap',
    disable   => 'autoname',
    disable   => 'clean_after_build',

    ($O{-f}) ? (enable => 'force_build') : () ,
  ));
  chdir($old);

  # ^find the generated *.so
  my $blddir="$trash/build/$name";
  my $soname="$name.so";

  my $out="$blddir/blib/arch/auto/$name/$soname";
  throw "XS build fail: '$soname'" if ! -f $out;

  # we copy the *.so to where XSLoader can find it
  #
  # this makes it so a module can work _without_
  # Inline ever being invoked...
  my $dst=shared_libp($name);
  rename $out,$dst;

  return;
};


# ---   *   ---   *   ---
# ^fetches the *.so

sub load($name) {
#  # get version
#  no strict 'refs';
#  my $version=sane_version(${"$name\::VERSION"});

#  # get path to package
#  my $fname=$name;
#  from_pkg($fname);
#
#  my $dir  = based($fname);
#  my $full = "$ENV{ARPATH}/lib/$dir/";

#  XSLoader::load($name,v0.00);
#
#  my $st=mem_new(1,8,0x00);
#  use Arstd::xd;
#  xd($st);
#  mem_del($st);
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
    hed   => null,
    obj   => {},
  };

  # ^iter through expanded list to fill it out
  my $hed=null;
  for(@file) {
    my $fcpy=$ARG;
    relto_mod($fcpy);
    extwap($fcpy,'pm');
    to_pkg($fcpy);

    # skip if no symbols exported for this file
    AR::reload($fcpy);
    next if ! $fcpy->can('XSHED');

    # record symbol data for each object file
    my $xs = $fcpy->XSHED();
    my $o  = Shb7::Path::obj_from_src($ARG);
    relto_root($o);

    $shwl->{obj}->{$o}=$xs;

    # now include the header for it ;>
    my $h=$ARG;
    extwap($h,'h');
    $shwl->{hed} .= orc($h) . "\n";

#    # ^and wrappers below that
#    for my $sym(@$xs) {
#      my $rtype=(! is_null($sym->{type}))
#        ? $sym->{type}
#        : 'void'
#        ;
#
#      my $args='void';
#      if(@{$sym->{args}}) {
#        $args=join ',',map {
#          "$ARG->{type} $ARG->{name}";
#
#        } @{$sym->{args}};
#      };
#
#      $hed .= "$rtype $sym->{name}($args);\n";
#    };
  };

  my $re=qr{static inline };
  $shwl->{hed}=~ s[$re][]smg;

  # dump table to disk
  store($shwl,$dst) or throw $dst;
  return $shwl;
};


# ---   *   ---   *   ---
1; # ret
