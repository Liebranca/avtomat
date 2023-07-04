#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT
# Base class for code emitters
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Emit;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $ON_NO_VERSION => 'v0.00.1b';
  Readonly our $ON_NO_AUTHOR  => 'ANON';

# ---   *   ---   *   ---
# transforms type to peso equivalent

sub typetrim($class,$typeref) {

  $$typeref=~ s[^\s*|\s*$][]sg;

  # temporal patch ;>
  $$typeref=~ s[inline][];

};

sub get_typetab($class) {

  no strict 'refs';
  my $out=${"$class\::Typetab"};

  use strict 'refs';

  return $out;

};

sub typecon($class,$type) {

  my $tab=$class->get_typetab();
  $class->typetrim(\$type);

  if(exists $tab->{$type}) {
    $type=$tab->{$type};

  };

  return $type;

};

# ---   *   ---   *   ---
# dummies, derived class implements if needed

sub boiler_open($class,$fname,%O) {return q{}};
sub boiler_close($class,$fname,%O) {return q{}};
sub xltab($class,%table) {return %table};

sub fnwrap($class,$name,$code,%O) {
  return $name.q{ }.$code;

};

sub datasec($class,$name,$type,@items) {
  return $type.q{ }.$name.q{ }.(join ',',@items);

};

# ---   *   ---   *   ---
# puts code in-between two pieces of boiler

sub codewrap($class,$fname,%O) {

  # defaults
  $O{add_guards} //= 0;

  $O{include}    //= [];
  $O{define}     //= [];
  $O{args}       //= [];

  $O{body}       //= $NULLSTR;

  $O{author}     //= $ON_NO_AUTHOR;
  $O{version}    //= $ON_NO_VERSION;

  # run code generation
  my $s=$NULLSTR;
  $s.=$class->boiler_open($fname,%O);

  my @code=(is_arrayref($O{body}))
    ? @{$O{body}}
    : $O{body}
    ;

  my @args=(is_arrayref($O{args}))
    ? @{$O{args}}
    : [@{$O{args}}]
    ;

#  for my $bit(@code) {
#
#    my $c_args=shift @args;
#
#    if(length ref $bit) {
#      $s.=$bit->(@$c_args);
#
#    } else {
#      $s.=$bit;
#
#    };
#
#  };

  $s.=$class->boiler_close($fname,%O);

  return $s;

};

# ---   *   ---   *   ---
1; # ret
