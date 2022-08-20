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
    q[%s frame has no autoload],
    args=>[$self->{-class}],

    lvl=>$AR_FATAL,

  ) unless defined $self->{-autoload}
  && exists $self->{-autoload}->{$key};

  $self->{-class}->$key(
    $self,@args

  );

};

# ---   *   ---   *   ---
1; # ret
