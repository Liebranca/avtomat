#!/usr/bin/perl
# ---   *   ---   *   ---
# TYPE:C
# A million aliases for
# the same effen pointer
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb

# ---   *   ---   *   ---
# deps

package Type::C;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Type;

  use Arstd::Array;
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


    q[sign_byte]     => ['int8_t'],
    q[byte]          => [
      'uint8_t','uchar','unsigned char'

    ],

    q[sign_word]     => ['int16_t','short'],
    q[word]          => ['uint16_t','ushort'],

    q[long_byte_str] => ['char*'],
    q[long_word_str] => ['wchar_t*'],

    q[dword]         => ['uint32_t','uint'],
    q[sign_dword]    => ['int32_t','int'],

    q[qword]         => [
      'uint64_t','ulong','size_t','uintptr_t',

    ],

    q[sign_qword]    => [
      'int64_t','long','intptr_t',

    ],

    q[real]          => ['float'],
    q[dreal]         => ['double'],

    q[nullarg]       => ['void'],

  );

# ---   *   ---   *   ---
# batch make type alias

sub batlis($class,$C,$peso) {

  my $star = $NULLSTR;
  my @out  = ("$C" => "$peso");


  $peso = "long_${peso}"
  if (! Type->is_str($peso));

  return @out,map {
    $star .= '*';
    "$C$star" => "${peso}_$ARG";

  } @{$Type::PTR_T_LIST};

};

# ---   *   ---   *   ---
1; # ret
