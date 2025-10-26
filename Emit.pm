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
# lib,

# ---   *   ---   *   ---
# deps

package Emit;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_arrayref is_coderef);

  use Arstd::Array qw(nkeys nvalues);

  use Arstd::Path qw(to_pkg find_subpkg);
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;
  use Arstd::throw;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

St::vconst {
  ON_NO_TITLE   => 'SCRATCH',
  ON_NO_VERSION => 'v0.00.1a',
  ON_NO_AUTHOR  => 'ANON',
};


# ---   *   ---   *   ---
# find emitter subclass matching name
# (c-)load it in if found

sub get_class($class,$name) {
  my $out=null;

  # nocase Emit::$name lookup
  my $fname=find_subpkg('Emit',$name);

  # ^make classname from filename
  if($fname) {
    $out=to_pkg($fname);
    cload($out);
  };

  return $out;
};


# ---   *   ---   *   ---
# transforms type to peso equivalent

sub typecon($class,$type) {
  my $re   =  qr{^Emit::};
  my $lang =  $class;
     $lang =~ s[$re][];

  my $out=Type::xlate($class,$type);
  return $out;
};


# ---   *   ---   *   ---
# dummies, derived class implements if needed

sub boiler_open($class,$fname,%O) {return q{}};
sub boiler_close($class,$fname,%O) {return q{}};

sub fnwrap($class,$name,$code,%O) {
  return $name.q{ }.$code;
};

sub datasec($class,$name,$type,@items) {
  return $type.q{ }.$name.q{ }.(join ',',@items);
};

sub tidy($class,$sref) {
  return $$sref;
};


# ---   *   ---   *   ---
# puts code in-between two pieces of boiler

sub codewrap($class,$fname,%O) {
  # defaults
  $O{guards}  //= 0;

  $O{ldo}     //= [];
  $O{lib}     //= [];
  $O{inc}     //= [];
  $O{def}     //= [];

  $O{body}    //= [q[]=>[]];

  $O{author}  //= $class->ON_NO_AUTHOR;
  $O{version} //= $class->ON_NO_VERSION;

  $O{tidy}    //= 0;


  # run code generation
  my $s=$class->boiler_open($fname,%O);

  is_arrayref($O{body})
  or throw_genbody();

  my @code=nkeys($O{body});
  my @args=nvalues($O{body});

  map {
    my $args=shift @args;

    $s.=(is_coderef($ARG))
      ? $ARG->(@$args)
      : $ARG
      ;

  } @code;


  $s .= $class->boiler_close($fname,%O);
  $s  = ($O{tidy})
    ? $class->tidy(\$s)
    : $s
    ;

  return $s;
};


# ---   *   ---   *   ---
# ^errme

sub throw_genbody() {
  throw(
    q[Body of [ctl]:%s must be an ]
  . q[array of [F=>ARGS]],

    args => ['codewrap'],
  );
};


# ---   *   ---   *   ---
1; # ret
