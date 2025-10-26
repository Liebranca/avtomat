#!/usr/bin/perl
# ---   *   ---   *   ---
# FRAME
# Context container
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Frame;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Scalar::Util qw(blessed);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Arstd::throw;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v2.00.5';
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


  # catch invalid
  throw sprintf(
    "%s frame has no autoload for '%s'",
    $self->{-class},$key,

  ) if ! exists $auto->{$key};

  return $self->{-class}->$key($self,@args);
};


# ---   *   ---   *   ---
# transfer of ownership

sub __ctltake($frame) {
  my $pkg=(caller)[0];

  push @{$frame->{-prev_owners}},
    $frame->{-owner_kls};

  $frame->{-owner_kls}=$pkg;
  return;
};

sub __ctlgive($frame) {
  my $pkg=pop @{$frame->{-prev_owners}};
  $frame->{-owner_kls}=$pkg;

  return;
};


# ---   *   ---   *   ---
# encode to binary

sub mint($self) {
  my $class = $self->{-class};
  my %out   = map {
    $ARG=>$self->{$ARG}

  } qw(
    -class
    -owner_kls
    -prev_owners

  );


  # have icebox?
  if($class->can('icepick')) {
    $self->icebox_clear(0);
  };

  # have specifics?
  if($class->can('mint_frame')) {
    %out=(%out,$class->mint_frame($self));

  # ^nope, just copy!
  } else {
    my $vars=$class->Frame_Vars();
    %out=(%out,map {
      $ARG=>$self->{$ARG}

    } keys %$vars);
  };

  delete $out{-autoload};
  return %out;
};


# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {
  my $type = $O->{-class};

  $O=$type->unmint_frame($O)
  if $type->can('unmint_frame');

  return $type->new_frame(%$O);
};


# ---   *   ---   *   ---
1; # ret
