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

  our $VERSION = v2.00.3;
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
# encode to binary

sub mint($self) {


  my %out=map {
    $ARG=>$self->{$ARG}

  } qw(
    -class
    -owner_kls
    -prev_owners

  );


  # have specifics?
  my $class=$self->{-class};
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
