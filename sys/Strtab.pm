#!/usr/bin/perl
# ---   *   ---   *   ---
# STRTAB
# Table of strings
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Strtab;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use parent 'St';

# ---   *   ---   *   ---

sub nit($class,@data) {

  my $i=0;

  my $indices={map {$ARG=>$i++} @data};

  $i=0;
  my $names={map {$i++=>$ARG} @data};

  my $tab=bless {

    name=>$names,
    idex=>$indices,

  },$class;

  return $tab;

};

# ---   *   ---   *   ---
1; # ret
