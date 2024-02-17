#!/usr/bin/perl
# ---   *   ---   *   ---
# TYPE:CPP
# OCTOPUS DOG
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb

# ---   *   ---   *   ---
# deps

package Type::Cpp;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Type;

  use Vault 'ARPATH';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;#a
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $TABLE => Vault::cached(


    q[TABLE] =>
      \&Type::xlatetab,q[Type::C],


    q[vec2]  => ['glm::vec2','vec2'],
    q[vec3]  => ['glm::vec3','vec3'],
    q[vec4]  => ['glm::vec4','vec4'],

    q[uvec2] => ['glm::uvec2','uvec2'],
    q[uvec3] => ['glm::uvec3','uvec3'],
    q[uvec4] => ['glm::uvec4','uvec4'],

    q[ivec2] => ['glm::ivec2','ivec2'],
    q[ivec3] => ['glm::ivec3','ivec3'],
    q[ivec4] => ['glm::ivec4','ivec4'],


    q[mat3]  => ['glm::mat3','mat3'],
    q[mat4]  => ['glm::mat4','mat4'],

  );

# ---   *   ---   *   ---
1; # ret
