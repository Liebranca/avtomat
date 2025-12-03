#!/usr/bin/perl
# ---   *   ---   *   ---
# SYNTAX CHECK
# perl -c
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Chk::Syntax;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ERRNO $EVAL_ERROR);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Arstd::Bin qw(orc);
  use Arstd::throw;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# entry point
#
# [0]: byte ptr ; class
# [1]: byte ptr ; filename
# [2]: byte ptr ; buf to exec
#
# [*]: buf defaults to orc(filename)
#
# [!]: this F throws on _any_ syntax warning
#
# [!]: do not pass code you don't trust
#      through this F -- it _will_ be executed

sub import {
  state $uid=0;
  return if is_null $_[1];

  $_[2]//=orc $_[1];


  # make fake package names;
  #
  # this is done to avoid dependency cycle,
  # in case package is being imported while
  # this F is running
  #
  # static uid makes it so this can be run
  # multiple times on the same file
  my $beg = "\npackage";
  my $re  = qr{$beg\s+([^;]+);};

  $_[2]=~ s[$re][$beg SyntaxCheck$uid\::${1};]smg;
  ++$uid;

  # executes the code to get warnings
  # throws on failure
  my @out=$_[0]->run($_[1],$_[2]);

  # restore package names and give
  $re   =  qr{$beg\s+SyntaxCheck\d+::([^;]+);};
  $_[2] =~ s[$re][$beg $1;]smg;

  return @out;
};


# ---   *   ---   *   ---
# executes the code to get warnings
# throws on failure
#
# [0]: byte ptr ; filename
# [1]: byte ptr ; buf to exec
#
# [!]: do not pass code you don't trust
#      through this F -- it _will_ be executed

sub run {
  my $class=shift; # drop class

  # discard garbage in errno ;>
  $ERRNO=0;

  # set signal handler (to catch error messages)
  # and then syntax check the program
  my ($errme,$psig)=$class->begcapt();
  $class->perlc($_[1]);

  # ^show error messages if any;
  # ^else syntax OK, restore signal handler
  throw(undef,$_[0],$errme)
  if $EVAL_ERROR || @$errme;

  $class->endcapt($psig);
  return ();
};


# ---   *   ---   *   ---
# makes array and connects it to warn signal
#
# this 'promises' it will be populated
# by warning messages at end of run
#
# [<]: byte  pptr ; new array
# [<]: stark      ; previous signal handler
#
# [!]: need to check if evaled code can undo this

sub begcapt {
  shift; # drop class

  my $errme = [];
  my $psig  = $SIG{__WARN__};

  # connect new to make promise
  $SIG{__WARN__}=sub {
    push @$errme,$_[0];
    return;
  };

  # ^remember to restore prev handler
  return ($errme,$psig);
};


# ---   *   ---   *   ---
# execs code to syntax check it
# yep, no other way around it
#
# [0]: byte ptr ; buf to exec
#
# [!]: do not pass code you don't trust
#      through this F -- it _will_ be executed

sub perlc {
  shift; # drop class
  eval "return;$_[0]";

  return;
};


# ---   *   ---   *   ---
# undoes begcapt, restoring the
# old signal handler
#
# [0]: stark ; signal handler

sub endcapt {
  shift; # drop class

  $SIG{__WARN__}=$_[0];
  return;
};


# ---   *   ---   *   ---
1; # ret
