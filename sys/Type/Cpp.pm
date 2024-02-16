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


    q[real_qword] => ['glm::vec2','vec2'],
    q[real_xword] => ['glm::vec4','vec4'],

    q[qword]      => ['glm::uvec2','uvec2'],
    q[xword]      => ['glm::uvec4','uvec4'],

    q[sign_qword] => ['glm::ivec2','ivec2'],
    q[sign_xword] => ['glm::ivec4','ivec4'],

    q[real_zword] => ['glm::mat4','mat4'],

  );

# ---   *   ---   *   ---
1; # ret
