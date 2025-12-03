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
  use Carp qw(croak);
  use English qw($ARG);
  use Module::Load 'none';
  use Symbol qw(delete_package);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Chk qw(is_null codefind);
  use Arstd::Path qw(from_pkg);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.03.2';
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

  return (! _is_loaded($pkg))
    ? reload($pkg,@_)
    : ()
    ;
};


# ---   *   ---   *   ---
# ^unconditional

sub reload {
  my $pkg=shift;

  Module::Load::load($pkg);
  $pkg->import(@_) if($pkg->can('import'));

  return;
};


# ---   *   ---   *   ---
# calls unimport method of package (if any)
# then removes it from INC

sub unload {
  # skip not loaded
  my $pkg   = shift;
  my $fname = "$pkg";
  from_pkg($fname);

  return if ! _is_loaded($pkg);

  # run exit sub if exists
  $pkg->unimport(@_) if($pkg->can('unimport'));

  # remove from INC
  delete_package($pkg);
  delete $INC{$fname};

  return;
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
  my $dst   = caller;
  my $flag  = {map {$ARG=>0} flagkey};

  # get the lib!
  my $base  = $ENV{ARLIB}//="$ENV{ARPATH}/lib/";
  my $basep = (! is_null $lib)
    ? "$base/$lib"
    : "$base"
    ;

  load(lib=>$base);
  return if ! @_;


  # get patterns
  my $pkg_re       = qr{::};
  my $term_re      = qr{;};
  my $beg_group_re = qr{^\(};
  my $end_group_re = qr{\);$};

  # walk passed args
  while(@_) {
    my $arg=shift;

    # arg is switch?
    if(exists $flag->{$arg}) {
      $flag->{$arg}=1;
      next;
    };


    # read line
    my @passed=grep {
    ! is_null($ARG)

    } split $pkg_re,$arg;

    my $sym=pop  @passed;
    my $pkg=join '::',@passed;


    # throw if no package!
    croak "No package provided"
    if is_null($pkg);

    # throw if no symbols!
    croak "No symbols provided"
    if is_null($sym);


    # have multiple symbols?
    my @sym=($sym);
    if($sym[0]=~ s[$beg_group_re][]) {
      while(@_) {
        last if $sym[-1]=~ s[$end_group_re][];
        push @sym,shift;
      };

      $sym[-1]=~ s[$end_group_re][];
    };

    # ^filter out blanks
    @sym=grep {! is_null($ARG)} @sym;


    # import mode:
    #
    # * just load the package
    # * run import method with @sym as args
    if($flag->{imp}) {
      # re-import?
      if($flag->{re}) {
        load($pkg,@sym);

      # ^nope, use conditional form
      } else {
        load($pkg,@sym);
      };

      next;
    };


    # load source package
    load($pkg);

    # making nested namespace?
    my $path=(! $flag->{'use'})
      ? lc $passed[-1] . '_'
      : ''
      ;

    # make alias declarations
    my @decl=map {
      croak "Undefined symbol: '$pkg\::$ARG'"
      if ! defined codefind($pkg,$ARG);

      "sub ${path}$ARG {goto \&$pkg\::$ARG};";

    } @sym;

    # ^put declarations in package
    my $decl=join "\n",(
      "package $dst {",
      @decl,
      '}'
    );

    # ^add symbol(s) to caller
    eval $decl;


    # reset flags for next run
    $flag->{$ARG}=0 for flagkey;
  };

  return;
};


# ---   *   ---   *   ---
1; # ret
