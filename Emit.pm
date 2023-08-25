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
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Arstd::Path;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.5;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $ON_NO_VERSION => 'v0.00.1b';
  Readonly our $ON_NO_AUTHOR  => 'ANON';

# ---   *   ---   *   ---
# find emitter subclass matching name
# (c-)load it in if found

sub get_class($class,$name) {

  my $out=$NULLSTR;

  # nocase Emit::$name lookup
  my $fname=find_subpkg('Emit',$name);

  # ^make classname from filename
  if($fname) {
    $out=fname_to_pkg($fname);
    cload($out);

  };


  return $out;

};

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

  $O{lib}        //= [];
  $O{inc}        //= [];
  $O{def}        //= [];

  $O{body}       //= [$NULLSTR=>[]];

  $O{author}     //= $ON_NO_AUTHOR;
  $O{version}    //= $ON_NO_VERSION;


  # run code generation
  my $s=$NULLSTR;
  $s.=$class->boiler_open($fname,%O);

  is_arrayref($O{body})
  or throw_genbody();

  my @code=array_keys($O{body});
  my @args=array_values($O{body});

  map {

    my $args=shift @args;

    $s.=(is_coderef($ARG))
      ? $ARG->(@$args)
      : $ARG
      ;

  } @code;

  $s.=$class->boiler_close($fname,%O);

  return $s;

};

# ---   *   ---   *   ---
# ^errme

sub throw_genbody() {

  errcaller();
  errout(

    q[Body of [ctl]:%s must be an ]
  . q[array of [F=>ARGS]],

    lvl  => $AR_FATAL,
    args => ['codewrap'],

  );

};

# ---   *   ---   *   ---
1; # ret
