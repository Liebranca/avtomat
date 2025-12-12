#!/usr/bin/perl
# ---   *   ---   *   ---
# AR/*
# Arcane Solutions
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package AR;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Module::Load 'none';
  use Symbol qw(delete_package);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null codefind);

  use Arstd::String qw(cat gstrip gsplit);
  use Arstd::Path qw(from_pkg);
  use Arstd::PM qw(rcaller);
  use Arstd::fatdump;
  use Arstd::throw;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.03.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# checks INC for package

sub is_loaded {
  my $fname=shift;
  from_pkg($fname);

  return _is_loaded($fname);
};
sub _is_loaded {
  return exists $INC{$_[0]};
};


# ---   *   ---   *   ---
# loads package if it's not
# already loaded!

sub load {
  # skip loaded package
  my $pkg   = shift;
  my $fname = "$pkg";
  from_pkg($fname);

  return (! _is_loaded($fname))
    ? reload($pkg,@_)
    : ()
    ;
};


# ---   *   ---   *   ---
# ^unconditional

sub reload {
  my $pkg=shift;
  my $dst=rcaller(__PACKAGE__);

  # run import on *calling* module
  my $args=fatdump \[@_],mute=>1,plain=>1;
  return eval(join("\n",
    "package $pkg {",
      "Module::Load::load($pkg);",
      "($pkg->can('import'))",
        "? $pkg->import($args)",
        ": ()",
        ";",
    "};",
  ));
};


# ---   *   ---   *   ---
# ^ doesn't use the calling package to
#   run the import method
#
# we use this for modules that are actually
# meant to be *run* as if they were executables,
# such as Chk::Syntax

sub run {
  my $pkg=shift;
  Module::Load::load($pkg);
  return ($pkg->can('import'))
    ? $pkg->import(@_)
    : ()
    ;
};

# ---   *   ---   *   ---
# calls unimport method of package (if any)
# then removes it from INC

sub unload {
  # skip not loaded
  my $pkg   = shift;
  my $fname = "$pkg";
  from_pkg($fname);

  return () if ! _is_loaded($pkg);

  # run exit sub if exists
  my @out=($pkg->can('unimport'))
    ? $pkg->unimport(@_)
    : ()
    ;

  # remove from INC
  delete_package($pkg);
  delete $INC{$fname};

  return @out;
};


# ---   *   ---   *   ---
# gets package from full
# subroutine path

sub pkgof {
  my ($subn,@pkg)=(reverse split qr{::},$_[0]);
  return join '::',reverse @pkg;
};


# ---   *   ---   *   ---
# load package from subroutine path

sub load_from_sub {
  my $path=shift;
  return if $path eq 'main';
  return load(pkgof($path),@_);
};


# ---   *   ---   *   ---
# give list of flags

sub flagkey {return qw(use lis imp re)};


# ---   *   ---   *   ---
# brings in stuff from sub-packages

sub import {
  my $class = shift;
  my $lib   = shift;
  my $flag  = {map {$ARG=>0} flagkey};

  # get the lib!
  my $base  = $ENV{ARLIB}//="$ENV{ARPATH}/lib/";
  my $basep = (! is_null $lib)
    ? "$base/$lib"
    : "$base"
    ;

  reload(lib=>$base);
  return if ! @_;

  # get array of expressions within passed string
  my $line=shift;
  my @line=gsplit($line,qr{\n});
  my @expr=(null);
  for(@line) {
    $expr[-1] .= " $ARG ";
    if($ARG=~ qr{\)?;$}) {
      push @expr,null;
    };
  };
  @expr=gstrip(@expr);
  duse($ARG) for @expr;

  return;
};


# ---   *   ---   *   ---
# ^procs import line

sub duse {
  my ($line,%O)=@_;
  $O{reload} //= 0;

  my ($cmd,$pkg,@args)=gsplit($line,qr{ +});
  @args=eval(join(' ',@args));

  # throw if no package!
  throw "No package provided"
  if is_null($pkg);

  # always import?
  if($O{reload}) {
    reload($pkg,@args);

  # ^nope, use conditional form
  } else {
    load($pkg,@args);
  };

  # making nested namespace?
  my @pkgpath=gsplit($pkg,qr{::});
  my $path=($cmd eq 'lis')
    ? lc $pkgpath[-1] . '_'
    : null
    ;

  # make alias declarations
  my $dst  = rcaller(__PACKAGE__);
  my @decl = map {
    throw "Undefined symbol: '$pkg\::$ARG'"
    if ! defined codefind($pkg,$ARG);

    # redecl warnings are a pain
    my $blk="{goto \&$pkg\::$ARG};";
#    if(defined codefind($dst,"${path}$ARG")) {
#      join("\n",
#        "no strict 'refs';",
#        "no warnings 'redefine';",
#        "*{\"${path}$ARG\"}=sub $blk",
#        "use warnings 'redefine';",
#        "use strict 'refs';",
#      );
#
#    } else {
      "sub ${path}$ARG $blk";
#    };

  } @args;

  # ^put declarations in package
  my $decl = join "\n",(
    "package $dst {",
      "no strict 'refs';",
      "no warnings 'redefine';",
      @decl,
      "use warnings 'redefine';",
      "use strict 'refs';",
    "};\n"
  );

  # ^add symbol(s) to caller
  eval $decl;
  return;
};


# ---   *   ---   *   ---
1; # ret
