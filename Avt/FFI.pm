#!/usr/bin/perl
# ---   *   ---   *   ---
# AVT FFI
# Interfaces with Platypus
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Avt::FFI;

  use v5.36.0;
  use strict;
  use warnings;

  use FFI::Platypus;
  use FFI::CheckLib;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;
  use Type;

  use Vault 'ARPATH';
  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

  }};

  our $Typetab=Vault::cached(

    '$Typetab',\$Typetab,
    \&xltab,

    q[byte]=>['uint8'],
    q[sbyte]=>['sint8'],
    q[wide]=>['uint16'],
    q[swide]=>['uint16'],

    q[long]=>['uint32'],
    q[slong]=>['sint32'],
    q[word]=>['uint64'],
    q[sword]=>['uint64'],

    q[byte_str]=>['string'],
    q[wide_str]=>['wstring'],

  );

# ---   *   ---   *   ---

sub nit($class) {

  my $olderr=Arstd::errmute();
  my $ffi=FFI::Platypus->new(api=>2);

  Arstd::erropen($olderr);

  # this mess of an edge case
  $ffi->load_custom_type(
    '::WideString'=>'wstring'

  );

  # set type aliases
  for my $ffi_type(keys %{$Typetab}) {

    my $alias=$Typetab->{$ffi_type};
    $ffi->type($ffi_type=>$alias)

  };

  # function types
  $ffi->type('(void)->void'=>'nihil');
  $ffi->type('(void*)->void'=>'stark');
  $ffi->type('(uint64)->uint64'=>'signal');

  return $ffi;

};

# ---   *   ---   *   ---

sub xltab(%table) {

  my $result={};

  for my $key(keys %table) {
  for my $indlvl(1..3) {

    my $peso_ind=$Type::Indirection_Key->[$indlvl-1];
    my $c_ind=q[*] x $indlvl;

    my $peso_type="${key}_$peso_ind";
    for my $ffi_type(@{$table{$key}}) {
      $result->{$ffi_type}=$key;
      $result->{$ffi_type.$c_ind}=$peso_type;

    };

  }};

  return $result;

};

# ---   *   ---   *   ---
1; # ret
