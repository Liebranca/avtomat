#!/usr/bin/perl
# ---   *   ---   *   ---
# ST
# Fundamental structures
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package St;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use Scalar::Util qw(blessed);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Frame;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {{}};

# ---   *   ---   *   ---
# is obj instance of class

sub is_valid($kind,$obj) {
  return blessed($obj) && $obj->isa($kind);

};

# ---   *   ---   *   ---
# create instance container

sub new_frame($class,%O) {

  my $vars=$class->Frame_Vars;
  map {$O{$ARG}//=$vars->{$ARG}} keys %$vars;

  $O{-class}=$class;

  my $frame=Frame::new(%O);
  return $frame;

};

# ---   *   ---   *   ---
1; # ret
