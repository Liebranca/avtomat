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
  use parent 'Shb7::Bk::front';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $INC_FILTER=>
    qr{^" | \.h(?:pp)?"$}x;

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  return Shb7::Bk::front::new(

    $class,

    lang    => 'C',

    bk      => 'gcc',
    entry   => 'main',

    %O,
    linking => 'cstd',

  );

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
# deduce include directories
# from the header path
#
# <system-headers> are
# excluded from out

sub incl_deduce($class,@inc) {

  my @out=Shb7::Bk::front->incl_deduce(
    grep {$ARG=~ $INC_FILTER} @inc

  );

  map {
    $ARG=~ s[$INC_FILTER][]sxmg

  } @out;

  return @out;

};

# ---   *   ---   *   ---
1; # ret
