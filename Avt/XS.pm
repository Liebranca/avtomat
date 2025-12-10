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

  use Arstd::String qw(cat strip);
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
  use Arstd::Fmat;
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

  our $VERSION = 'v0.00.5a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# compiles XS from shwl

sub build($shwl,$bld,$pkg,%O) {
  # defaults
  $O{-f} //= 0;

  # get file name from package
  my $fname=$pkg;
  from_pkg($fname);
  extcl($fname);

  # ^split it up
  my ($dir,$outf)=(dirof($fname),basef($fname));
  relto_root($dir);
  if($dir=~ q{^\.\.?}) {
    $dir=null;
  };

  # check whether we can skip compilation
  my $dst  = shared_libp($dir,"${fname}XS");
  my $ok   = 0;
  for my $obj(@{$shwl->{obj}}) {
    $ok+=int(moo($dst,$obj));
  };
  return if ! $ok;

  # make path if need
  my $trash=ctrashp() . '/.XS';
  reqdir($trash);
  reqdir(dirof($dst));

  # generate XS code with wrappers for
  # all exported symbols
  xsgen($trash,$pkg,$shwl);

  # get a string with the compiler flags we use
  my $ccflag=join ' ',(
    @{$bld->{flag}},
    Shb7::Bk::cmam::oflg(),
  );

  # add dependencies to lib path
  push @{$bld->{lib}},(
    @{$shwl->{dep}},
    "-L" . libdirp($dir),
    "-l$outf"
  );
  dupop($bld->{lib});

  # generate and run makefile
  my $makefile=makegen(
    $trash,
    NAME      => "${pkg}XS",
    LIBS      => $bld->libline(),
    INC       => $bld->incline(),
    CCFLAGS   => $ccflag,
    MYEXTLIB  => static_libp($dir,$outf),
    TYPEMAPS  => [Avt::XS::Type->table()],
    VERSION   => $shwl->{VERSION},
  );
  my $old=getcwd();
  chdir $trash;
  `perl $makefile && make`;
  chdir $old;

  # find the generated *.so
  #
  # NOTE: the double '$outf' is not a typo,
  #       *this* is the correct folder structure
  #
  #       ... no further comment ;>
  my $blib = "$trash/blib/arch/auto/$dir";
  my $out  = "$blib/${outf}XS/${outf}XS.so";
  throw "'$out'\nXS build fail" if ! -f $out;

  # we move the *.so to where XSLoader can find it
  rename $out,$dst;

  # finally, make a perl module to serve as
  # container for the generated xsubs
  pmgen($pkg,$shwl);
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
  extcl($fname);
  $fname.="XS.xs";

  # we SLAP recognition _right_ on the sauce
  my $author=(
    "static const char* AUTHOR="
  . "\"$shwl->{AUTHOR}\";\n"
  );

  # write *.xs file and give
  reqdir(dirof("$path/$fname"));
  owc("$path/$fname",join("\n",
    $shwl->{hed},
    $author,
    "MODULE = ${pkg}XS PACKAGE = $pkg",
    "PROTOTYPES: DISABLE",
    "VERSIONCHECK: ENABLE",
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
# generates a perl module from the shwl

sub pmgen($pkg,$shwl) {
  # paste in dependencies
  my $body="package $pkg;" . q[
    use v5.42.0;
    use strict;
    use warnings;

    use English qw($ARG);
    use lib "$ENV{ARPATH}/lib/";
  ] . cat(map {"use $ARG;\n"} @{$shwl->{pm}});

  # add symbol names for export
  $body .= q[
    use Exporter 'import';
    our @EXPORT_OK=qw(
  ];

  for my $src(@{$shwl->{src}}) {
  for my $sym(@$src) {
    $body .= "$sym->{name}\n";
  }};
  $body .= ");\n";

  # put in version data and load the xsubs
  $body .= join("\n",
    "our \$VERSION = '$shwl->{VERSION}';",
    "our \$AUTHOR  = '$shwl->{AUTHOR}';",
    "require XSLoader;",
    "XSLoader::load(q[${pkg}XS],\$VERSION);",
    "1; # ret\n"
  );

  $body=Arstd::Fmat::tidyup(\$body,filter=>0);

  # make filepath from package name
  my $fname=$pkg;
  from_pkg($fname);

  # ^split it up
  my ($dir,$outf)=(
    dirof($fname),
    basef($fname)
  );
  relto_root($dir);
  if($dir=~ q{^\.\.?}) {
    $dir=null;
  };
  $dir=libdirp($dir);

  # write to file
  reqdir($dir);
  owc("$dir/$outf",$body);

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
    pm    => [],
    obj   => [],
    src   => [],
    hed   => join("\n",
      q[#include "EXTERN.h"],
      q[#include "perl.h"],
      q[#include "XSUB.h"],
      null,
    ),
  };

  my $info={
    VERSION => [],
    AUTHOR  => [],
  };

  # ^iter through expanded list to fill it out
  no strict 'refs';
  for(@file) {
    # get perl module generated by CMAM
    # for this compiled object
    my $fcpy=$ARG;
    relto_mod($fcpy);
    extwap($fcpy,'pm');
    to_pkg($fcpy);

    # ^now load pkg to get symbol table
    AR::reload($fcpy);
    my $xs=($fcpy->can('XSHED'))
      ? $fcpy->XSHED()
      : []
      ;

    # get package info ;>
    push @{$info->{VERSION}},${"$fcpy\::VERSION"};
    push @{$info->{AUTHOR}},${"$fcpy\::AUTHOR"};

    # record symbol data for each object file
    my $o=Shb7::Path::obj_from_src($ARG);
    relto_root($o);

    push @{$shwl->{obj}},$o;
    push @{$shwl->{src}},$xs;
    push @{$shwl->{pm}},$fcpy;

    # now include the header for it ;>
    my $h=$ARG;
    extwap($h,'h');
    $shwl->{hed} .= "#include \"$h\"\n";
  };
  use strict 'refs';

  # merge package authors into one string
  dupop($info->{AUTHOR});
  $shwl->{AUTHOR}=join q[&&],@{$info->{AUTHOR}};

  # make final version number
  my $version_re=qr{^v?
    (?<major>\d+) \.
    (?<minor>\d+) \.
    (?<patch>\d+)
    (?<tag>.*)
  $}x;

  my $version={
    major => 0,
    minor => 0,
    patch => 0,
    tag   => '',
  };

  for my $s(@{$info->{VERSION}}) {
    # we actually have to ignore version tags
    # due to XSLoader being too thick to
    # understand that 'version' is just a string
    my ($major,$minor,$patch)=($s=~ $version_re);
    $major //= 0;
    $minor //= 0;
    $patch //= 0;

    # lazy aggregate
    if($major > $version->{major}) {
      $version->{major}=$major;
    };
    $version->{minor} += $minor;
    $version->{patch} += $patch;
  };

  $shwl->{VERSION}="v" . join('.',
    $version->{major},
    sprintf("%02u",$version->{minor}),
    sprintf("%04u",$version->{patch}),
  );

  # dump table to disk
  store($shwl,$dst) or throw $dst;
  return $shwl;
};


# ---   *   ---   *   ---
1; # ret
