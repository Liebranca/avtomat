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

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $ON_NO_AUTHOR=>'ANON-DEV';

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
  $O{add_guards}//=0;
  $O{include}//=[];
  $O{define}//=[];
  $O{body}//=$NULLSTR;
  $O{args}//=[];
  $O{author}//=$ON_NO_AUTHOR;

  my $s=$NULLSTR;

  $s.=$class->boiler_open($fname,%O);

  if(length ref $O{body}) {
    my $call=$O{body};
    $s.=$call->($fname,@{$O{args}});

  } else {
    $s.=$O{body};

  };

  $s.=$class->boiler_close($fname,%O);

  return $s;

};

# ---   *   ---   *   ---
1; # ret
