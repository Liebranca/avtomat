#!/usr/bin/perl
# ---   *   ---   *   ---
# VIA HARBOR
# Because 'port' means
# something else entirely
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Via::Harbor;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use IO::Socket::UNIX;
  use Time::HiRes qw(usleep);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Cask;
  use Arstd::Array;

  use parent 'Via';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# (pre)destructor

sub sink($class,$frame=undef,$idex=1) {

  my $self=$frame->{harbors}->view($idex-1);

  # remove file
  if(-e $self->{path}) {
    unlink $self->{path};

  };

  # give back slot
  if($frame && $frame->{harbors}) {
    $frame->{harbors}->take($idex-1);

  };

  return 0;

};

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,$name) {

  my $self=Via::nit($class,$frame,$name);

  # TODO: move directly to net
  # list of other sockets
  $self->{routes}=Cask->nit();


  # received shipments
  $self->{stock}=[];

  # scheduled tasks
  $self->{orders}=[];

  # id
  $self->{idex}=
    1+$frame->{harbors}->give($self);

  $self->{name}.=
    $Via::NET_RS.$self->{idex};


  $self->{net}=$frame->{net};

  return $self;

};

# ---   *   ---   *   ---

sub get_peer(

  # implicit
  $class,$frame,

  # actual
  $name,
  $idex=1,

) {

  my $search=

    $frame->{name}.$Via::NET_RS.
    $name.$Via::NET_RS.

    $idex

  ;

  my @values = array_values($frame->{harbors});
  my @found  = grep {
    $ARG->{name} eq $search

  } @values;

  return $found[0];

};

# ---   *   ---   *   ---
# adds target to trade routes

sub open_route($self,$path) {

  my $dst=$self->get_sock(

    Type => SOCK_STREAM(),
    Peer => $path,

  );

  $self->{routes}->give($dst);
  return $dst;

};

# ---   *   ---   *   ---
# sends a vessel towards other harbor(s)

sub ship($self,@crates) {

  my @harbors=array_keys(\@crates);
  my @shipments=array_values(\@crates);

  # deliver the goods
  while(@harbors && @shipments) {

    my $dst=shift @harbors;
    my $pkg=shift @shipments;

    $dst->send($pkg);
    $dst->shutdown(SHUT_WR);

    $dst->recv($pkg, 64);
    say "arrived $pkg";

    $dst->close();

  };

};

# ---   *   ---   *   ---
1; # ret
