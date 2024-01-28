#!/usr/bin/perl
# ---   *   ---   *   ---
# FRAME
# Icebox
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Frame;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Scalar::Util qw(blessed);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::IO;

# ---   *   ---   *   ---
# info

  our $VERSION = v2.00.2;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# invokes class constructor

sub new($frame,@args) {
  return $frame->{-class}->new($frame,@args);

};

# ---   *   ---   *   ---
# dupli of St's version

sub is_valid($kind,$obj) {
  return blessed($obj) && $obj->isa($kind);

};

# ---   *   ---   *   ---
# builds a new container

sub _new($class,%O) {

  if(exists $O{-autoload}) {

    $O{-autoload}={
      map {$ARG=>0} @{$O{-autoload}}

    };

  } else {
    $O{-autoload}={};

  };

  my $frame=bless \%O,$class;
  return $frame;

};

# ---   *   ---   *   ---
# load sub when called from
# icebox rather than ice

sub AUTOLOAD {

  our $AUTOLOAD;

  my $key  = $AUTOLOAD;
  my @args = @_;

  my $self = shift @args;
  my $auto = $self->{-autoload};

  return if $key=~ m[::DESTROY$];
  $key=~ s[^Frame::][];

  errout(

    q[%s frame has no autoload for '%s'],

    args => [$self->{-class},$key],
    lvl  => $AR_FATAL,

  ) unless exists $auto->{$key};

  return $self->{-class}->$key($self,@args);

};

# ---   *   ---   *   ---
# transfer of ownership

sub __ctltake($frame) {

  my $pkg=(caller)[0];

  push @{$frame->{-prev_owners}},
    $frame->{-owner_kls};

  $frame->{-owner_kls}=$pkg;

};

sub __ctlgive($frame) {

  my $pkg=pop @{$frame->{-prev_owners}};
  $frame->{-owner_kls}=$pkg;

};

# ---   *   ---   *   ---
1; # ret
