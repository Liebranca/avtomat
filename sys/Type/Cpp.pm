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
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Type;
  use parent 'Type::C';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub from_peso {return (
  # include C types
  Type::C->from_peso(),

  # ^append C++ types
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
)};

# ---   *   ---   *   ---
1; # ret
