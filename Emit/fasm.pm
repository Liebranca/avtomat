#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT FASM
# speaks aramaic...
# like el masi7 ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Emit::fasm;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Fmat;

  use Arstd::Path;
  use Arstd::Array;

  use Shb7::Path;
  use Shb7::Build;

  use Tree;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Emit::Std;

  use parent 'Emit';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

# ---   *   ---   *   ---
# file prologue

sub boiler_open($class,$fname,%O) {

  state $imphed=q[

# ---   *   ---   *   ---
# get importer

if ~ defined loaded?Imp
  include '%ARPATH%/forge/Imp.inc'

end if

# ---   *   ---   *   ---
# deps

];

  # get load order
  my $i    = 0;
  my $ldo  = $O{ldo};

  # ^stirr
  my $imps = join $NULLSTR,map {

    my $lib=$ldo->[($ARG*2)+0];
    my $inc=$ldo->[($ARG*2)+1];

    "lib $lib\n" . (join "\n",map {
      "  use $ARG"

    } @$inc)

    . "\n\nimport\n"
    . "\n# ---   *   ---   *   ---\n";

  } 0..(@$ldo/2)-1;


  # TODO: settable format
  my $fmat = "format ELF64 executable 3";

  my $out  = "$fmat\n$imphed$imps";
     $out .= "\nentry _start\n";

  return $out;

};

# ---   *   ---   *   ---
# ^epilogue

sub boiler_close($class,$fname,%O) {

  return join "\n",

  "\n\nalign \$10",
  "_start:",
  "  call $O{entry}",
  "  exit",

;

};

# ---   *   ---   *   ---
# placeholder: code formatting

sub tidy($class,$sref) {
  return $$sref;

};

# ---   *   ---   *   ---
# derive package name from
# name of file

sub get_pkg($class,$fname) {
  my $dir=parof($fname);
  return fname_to_pkg($fname,shpath($dir));

};

# ---   *   ---   *   ---
1; # ret
