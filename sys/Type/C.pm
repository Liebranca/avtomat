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

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# batch make type alias

sub batlis($class,$C,$peso) {

  return "$C" => "$peso"
  if $peso=~ qr{^(?:nullarg|long|longptr)$};

  return (

    "$C" => "$peso",

    (! Type->is_str($peso))
      ? ("$C*"  => "$peso long",
         "$C*"  => "$peso longptr",
         "$C**" => "long pptr")

      : ("$C"   => "${peso}ptr",
         "$C*"  => "long pptr")
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

BEGIN {

  St::vconst {

    Table  => {},
    RTable => {},

  };


  Type::xlatetab(

    __PACKAGE__,

    q[sign byte]      => ['char','int8_t'],
    q[byte]           => [
      'unsigned char','uint8_t'

    ],

    q[sign word]      => ['short','int16_t'],
    q[word]           => [
      'unsigned short','uint16_t'

    ],

    q[byte cstr long] => ['char*'],
    q[wide cstr long] => ['wchar_t*'],

    q[dword]=>['unsigned int','uint32_t'],

    q[sign dword]     => ['int','int32_t'],

    q[qword]          => [
      'unsigned long','size_t',
      'uintptr_t','uint64_t'

    ],

    q[sign qword]     => [
      'long','intptr_t','int64_t'

    ],

    q[real]           => ['float'],
    q[dreal]          => ['double'],

    q[nullarg]        => ['void'],
    q[longptr]        => ['void*'],
    q[long]           => ['void*'],

  ) if ! %{__PACKAGE__->Table};

};


# ---   *   ---   *   ---
1; # ret
