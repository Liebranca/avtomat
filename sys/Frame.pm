#!/usr/bin/perl
# ---   *   ---   *   ---
# FRAME
# Instance containers
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

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::IO;

# ---   *   ---   *   ---
# invokes class constructor

sub nit($frame,@args) {
  return $frame->{-class}->nit(
    $frame,@args

  );

};

# ---   *   ---   *   ---
# builds a new container

sub new(%O) {

  if(exists $O{-autoload}) {

    $O{-autoload}={
      map {$ARG=>1} @{$O{-autoload}}

    };

  };

  my $frame=bless \%O;
  return $frame;

};

# ---   *   ---   *   ---

sub AUTOLOAD {

  our $AUTOLOAD;

  my $key=$AUTOLOAD;
  my @args=@_;

  my $self=shift @args;

  return if $key=~ m[::DESTROY$];
  $key=~ s[^Frame::][];

  errout(
    q[%s frame has no autoload for '%s'],
    args=>[$self->{-class},$key],

    lvl=>$AR_FATAL,

  ) unless defined $self->{-autoload}
  && exists $self->{-autoload}->{$key};

  $self->{-class}->$key(
    $self,@args

  );

};

# ---   *   ---   *   ---

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
