#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT C++
# octopus-dog spitter
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb
# ---   *   ---   *   ---

# deps
package Emit::Cpp;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Vault;
  use Type;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;
  use parent 'Emit::C';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;#a
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# GBL:LIS

  use Type::Cpp;

  Readonly our $TYPETAB=>
    $Type::Cpp::TABLE;


# ---   *   ---   *   ---
# boilerpaste open

sub open_guards($class,$fname) {

  return join "\n",

    "#ifndef __${fname}_H__",
    "#define __${fname}_H__",

    "\n"

  ;

};

# ---   *   ---   *   ---
# boilerpaste close

sub close_guards($class,$fname) {
  return "#endif // __${fname}_H__\n";

};

# ---   *   ---   *   ---
1; #ret
