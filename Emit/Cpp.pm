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

  our $VERSION=v0.00.2;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $TYPES=>[

    q[real2]   => ['glm::vec2','vec2'],
    q[real3]   => ['glm::vec3','vec3'],
    q[real4]   => ['glm::vec4','vec4'],

    q[dword2]  => ['glm::uvec2','uvec2'],
    q[dword3]  => ['glm::uvec3','uvec3'],
    q[dword4]  => ['glm::uvec4','uvec4'],

    q[sdword2] => ['glm::ivec2','ivec2'],
    q[sdword3] => ['glm::ivec3','ivec3'],
    q[sdword4] => ['glm::ivec4','ivec4'],

    q[real9]   => ['glm::mat3','mat3'],
    q[real16]  => ['glm::mat4','mat4'],

  ];


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
# GBL

  our $Typetab=Vault::cached(

    'Typetab',

    \&Emit::C::xltab,
    (@{$Emit::C::TYPES},@$TYPES)

  );

# ---   *   ---   *   ---
1; #ret
