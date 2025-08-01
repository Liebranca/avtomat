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
  use Module::Load qw(load);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Chk qw(is_null codefind);


# ---   *   ---   *   ---
# info

  our $VERSION = v0.03.1;
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# checks INC for package

sub is_loaded {
  my $re    = qr{::};
  my $fname = shift;

  $fname=~ s[$re][/]g;

  return int grep {$ARG eq "$fname.pm"} keys %INC;

};


# ---   *   ---   *   ---
# [c]onditionally load
#
# loads package if it's not
# already loaded!

sub cload {
  load $_[0] if ! is_loaded $_[0];
  return;

};


# ---   *   ---   *   ---
# ^runs import method!

sub cloadi {
  my $pkg=shift;
  load $pkg,@_ if ! is_loaded $pkg;

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

sub cloads {
  return if $_[0] eq 'main';
  return cload pkgof $_;

};


# ---   *   ---   *   ---
# ^forces calling of import method

sub cloadis {
  my $path=shift;
  return if $path eq 'main';
  return cloadi pkgof($path),@_;

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
  my $base=$ENV{ARLIB}//="$ENV{ARPATH}/lib/";
  load lib=>(! is_null $lib)
    ? "$base/$lib"
    : "$base"
    ;

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
        load $pkg,@sym;

      # ^nope, use conditional form
      } else {
        cloadi $pkg,@sym;

      };

      next;

    };


    # load source package
    cload $pkg;

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
