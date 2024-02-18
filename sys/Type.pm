#!/usr/bin/perl
# ---   *   ---   *   ---
# TYPE
# I'd rather call it 'width'
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Type;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;

  use Type::MAKE;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    sizeof
    packof
    typeof

    typefet
    typedef
    layas

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.04.0;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get bytesize of type

sub sizeof($name) {

  my $type=typefet($name);

  return (defined $type)
    ? $type->{sizeof}
    : throw_invalid_type($name)
    ;

};

# ---   *   ---   *   ---
# get packing fmat for type

sub packof($name) {

  # these are special-cased (for now!)
  my $tab={
    'cstr'   => 'Z',
    'plcstr' => '$Z',

  };

  return    $tab->{lc $name}
  if exists $tab->{lc $name};


  # ^else fetch from table
  my $type=typefet($name);

  return (defined $type)
    ? $type->{packof}
    : throw_invalid_type($name)
    ;


};

# ---   *   ---   *   ---
# get type-list for pack
# accto provided bytesize

sub typeof($size) {

  my @out=();

  map {

    my $ezy=sizeof($ARG);

    while ($size >= $ezy) {
      push @out,$ARG;
      $size-=$ezy;

    };

  } qw(qword dword word byte);


  return @out;

};

# ---   *   ---   *   ---
# shorthands: check against re

sub is_valid($class,$name) {
  return defined typefet($name);

};

sub is_str($class,$name) {
  return $name=~ $Type::MAKE::RE->{str_t};

};

sub is_ptr($class,$name) {
  return $name=~ $Type::MAKE::RE->{ptr_t};

};

# ---   *   ---   *   ---
# completes a peso => (lang)
# translation table

sub xlatetab($langclass,@tab) {

  # array as hash
  my $ti=0;

  my @tk=array_keys(\@tab);
  my @tv=array_values(\@tab);

  # ^walk
  return { map {

    my $peso = $ARG;
    my $lang = $tv[$ti++];

    map {$langclass->batlis($ARG,$peso)} @$lang;


  } @tk };


};

# ---   *   ---   *   ---
1; # ret
