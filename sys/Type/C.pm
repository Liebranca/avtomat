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
# lib,

# ---   *   ---   *   ---
# deps

package Type::C;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Type;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# batch make type alias

sub batlis($class,$C,$peso) {
  return "$C" => "$peso"
  if $peso=~ qr{^(?:null|ptr)$};

  return (
    "$C" => "$peso",

    (! Type->is_str($peso))
      ? ("$C*"  => "$peso ptr",
         "$C**" => "$peso pptr")

      : ("$C*"  => "$peso ptr")
      ,
  );
};


# ---   *   ---   *   ---
# ^adds entry to table

sub add($class,$C,$peso) {
  my $have={$class->batlis($C,$peso)};
  map {
    $class->Table->{$ARG}=$have->{$ARG};
    $class->RTable->{$have->{$ARG}}=$ARG;

  } grep {
    ! exists $class->Table->{$ARG};

  } keys %$have;


  return;
};


# ---   *   ---   *   ---
# ROM

St::vconst {
  Table  => {},
  RTable => {},
};

sub from_peso {return (
  q[sign byte] => ['char','int8_t'],
  q[byte]      => [
    'unsigned char','uint8_t'
  ],

  q[sign word] => ['short','int16_t'],
  q[word]      => [
    'unsigned short','uint16_t'
  ],

  q[sign dword] => ['int','int32_t'],
  q[dword]      => ['unsigned int','uint32_t'],

  q[sign qword] => [
    'long','intptr_t','int64_t'
  ],
  q[qword] => [
    'unsigned long','size_t',
    'uintptr_t','uint64_t'
  ],

  q[cstr]  => ['char*'],
  q[plstr] => ['wchar_t*'],

  q[real]  => ['float'],
  q[dreal] => ['double'],

  q[null]  => ['void'],
  q[ptr]   => ['void*'],
)};


# ---   *   ---   *   ---
# ^generate table

sub import {
  my $class=shift;

  # skip if default types already built
  return if int keys %{$class->Table};

  # else build
  Type::xlatetab($class,$class->from_peso());
  return;
};


# ---   *   ---   *   ---
1; # ret
