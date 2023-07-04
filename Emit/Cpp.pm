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
  use Peso::Ipret;

  use parent 'Emit::C';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $TYPES=>[

    q[real2]  => ['glm::vec2','vec2'],
    q[real3]  => ['glm::vec3','vec3'],
    q[real4]  => ['glm::vec4','vec4'],

    q[brad2]  => ['glm::uvec2','uvec2'],
    q[brad3]  => ['glm::uvec3','uvec3'],
    q[brad4]  => ['glm::uvec4','uvec4'],

    q[sbrad2] => ['glm::ivec2','ivec2'],
    q[sbrad3] => ['glm::ivec3','ivec3'],
    q[sbrad4] => ['glm::ivec4','ivec4'],

    q[real9]  => ['glm::mat3','mat3'],
    q[real16] => ['glm::mat4','mat4'],

  ];

# ---   *   ---   *   ---

  Readonly our $OPEN_GUARDS=>

q[#ifndef __$:fname;>_H__
#define __$:fname;>_H__
];


# ---   *   ---   *   ---

  Readonly our $CLOSE_GUARDS=>
q[#endif // __$:fname;>_H__
];

# ---   *   ---   *   ---
# GBL

  our $Typetab=Vault::cached(

    'Typetab',

    \&Emit::C::xltab,
    (@{$Emit::C::TYPES},@$TYPES)

  );

# ---   *   ---   *   ---
# test

use Avt::CRun;
use Fmat;

my $gen={

  fname => './cpptest',
  lang  => 'Cpp',

# ---   *   ---   *   ---
# PROTO-SCRATCH

calls => [

  # TODO: class-wraps for hashref
  {

    kls  => 'codestr',
    fn   => 'ident',

    args => [],

  }

];

# ---   *   ---   *   ---

  body  => \&Emit::C::mfwrap,

  args  => [q[
    printf("HELLO\n");

  ]],

  syshed=>[qw(
    cstdio

  )],

  usrhed=>[qw(
    gaoler/Plane.hpp
    sin/mesh/Frame.hpp

  )],

};

Avt::CRun->exgen(['f','f'],$gen);

# ---   *   ---   *   ---
1; #ret
