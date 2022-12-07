#!/usr/bin/perl
# ---   *   ---   *   ---
# DEPSMAKE
# Dependency finder for MAM
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Avt::Depsmake;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Cwd qw(abs_path);

# ---   *   ---   *   ---
# global state

  my $Class;
  my $Modname;

  my $Pkg;
  my $Fname;
  my $Line;

# ---   *   ---   *   ---

sub import(@args) {

  ($Class,$Modname)=@args;
  ($Pkg,$Fname,$Line)=caller;

};

# ---   *   ---   *   ---

INIT {

  my @dst      = ();

  my $path_re  = abs_path(glob(q{~}));
  my $trash_re = qr{/.trash};

  $re=qr{$re};

  for my $path(values %INC) {

    next if $path eq __FILE__;

    if($path=~ $path_re) {

      my $alt=$path;
      $alt=~ s{/lib/} {/.trash/$Modname/};

      if(-d $alt) {$path=$alt};

      $path=~ s[$trash_re][];
      push @dst,$path;

    };

  };

  say {*STDOUT} $Fname,"\n",(join q[,],@dst);

};

# ---   *   ---   *   ---
1; # ret
