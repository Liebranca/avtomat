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

  use Arstd::Array;
  use Arstd::IO;

  use Type;

  use Vault 'ARPATH';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;#a
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $Typetab=Vault::cached(

    '$Typetab',\$Typetab,
    \&xltab,

    q[byte]=>['uint8'],
    q[sbyte]=>['sint8'],
    q[wide]=>['uint16'],
    q[swide]=>['sint16'],

    q[brad]=>['uint32'],
    q[sbrad]=>['sint32'],
    q[word]=>['uint64'],
    q[sword]=>['sint64'],

    q[byte_str]=>['string'],
    q[wide_str]=>['wstring'],

    q[pe_void]=>['opaque'],

  );

# ---   *   ---   *   ---
# GBL

  our $Instances = [];
  our $Closures  = {};

# ---   *   ---   *   ---
# give FFI object by id
# create new if missing

sub get_instance($class,$idex=0) {

  my $out=undef;

  if(!defined $Instances->[$idex]) {
    $out=$class->nit();

  } else {
    $out=$Instances->[$idex];

  };

  return $out;

};

# ---   *   ---   *   ---
# makes persistent closures

sub sticky($class,$coderef) {

  my $out=undef;

  if(! exists $Closures->{$coderef}) {
    my $ice = $class->get_instance();
    $out    = $ice->closure($coderef);

    $out->sticky();
    $Closures->{$coderef}=$out;

  } else {
    $out=$Closures->{$coderef};

  };

  return $out;

};

# ---   *   ---   *   ---

sub nit($class) {

  my $olderr=errmute();
  my $ffi=FFI::Platypus->new(api=>2);

  erropen($olderr);

  # this mess of an edge case
  $ffi->load_custom_type(
    '::WideString'=>'wstring'

  );

  my @keys=array_keys($Typetab);
  my @values=array_values($Typetab);

  # set type aliases
  while(@keys && @values) {

    my $ffi_type=shift @keys;
    my $alias=shift @values;

# ---   *   ---   *   ---
# NOTE; lyeb@IBN-3DILA on 08/06/22 23:31:54
#
# we can't point to wstring? what is this?
#
# don't even tell me why, I can already tell
# the reason is monumentally stupid

    if($ffi_type=~ m[^wstring\*+]) {
      $ffi_type='opaque*'; # suck it

    };

    $ffi->type($ffi_type=>$alias)

  };

  # function types
  $ffi->type('(void)->void'=>'nihil');

# ---   *   ---   *   ---
# NOTE: lyeb@IBN-3DILA on 08/07/22 00:13:04
#
# 'void pointer not allowed'? shame on you...

  $ffi->type('(opaque)->void'=>'stark');
  $ffi->type('(uint64)->uint64'=>'signal');

  return $ffi;

};

# ---   *   ---   *   ---

sub xltab(@table) {

  my $result=[];

  my @keys=array_keys(\@table);
  my @values=array_values(\@table);

  while(@keys && @values) {
    my $key=shift @keys;
    my $value=shift @values;

    for my $ffi_type(@$value) {
        push @$result,$ffi_type=>$key;

    };

# ---   *   ---   *   ---

  for my $indlvl(1..3) {

    my $peso_ind=$Type::Indirection_Key->[$indlvl-1];

    my $c_ind=q[*] x $indlvl;
    my $peso_type="${key}_$peso_ind";

    for my $ffi_type(@$value) {

      my $ctype;
      if($indlvl==1) {
        $ctype="$ffi_type$c_ind";

      } else {
        $ctype='opaque*';

      };

      push @$result,$ctype=>$peso_type;

    };

  }};

  return $result;

};

# ---   *   ---   *   ---
1; # ret
