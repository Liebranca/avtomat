#!/usr/bin/perl
# ---   *   ---   *   ---
# TYPE:PLATYPUS
# Slightly less annoying
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb

# ---   *   ---   *   ---
# deps

package Type::Platypus;

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


    q[byte]          => ['uint8'],
    q[word]          => ['uint16'],
    q[dword]         => ['uint32'],
    q[qword]         => ['uint64'],

    q[sign_byte]     => ['sint8'],
    q[sign_dword]    => ['sint32'],
    q[sign_word]     => ['sint16'],
    q[sign_qword]    => ['sint64'],

    q[long_byte_str] => ['string'],
    q[long_word_str] => ['wstring'],

    q[real]          => ['float'],
    q[dreal]         => ['double'],

    q[nullarg]       => ['opaque'],

  );

# ---   *   ---   *   ---
1; # ret
