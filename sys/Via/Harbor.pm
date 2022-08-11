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

  our $VERSION=v0.00.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $UNLOAD="\x{24}\x{17}";
  our $UNLOAD_RE=qr{\x24\x17$}x;

# ---   *   ---   *   ---
# (pre)destructor

sub sink($class,$frame,$idex) {

  my $self=$frame->{harbors}->view($idex);

  # remove file
  if(-e $self->{path}) {
    unlink $self->{path};

  };

  # give back slot
  if($frame && $frame->{harbors}) {
    $frame->{harbors}->take($idex);

  };

  return undef;

};

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,$name) {

  my $self=Via::nit($class,$frame,$name);

  # list of other sockets
  $self->{routes}=Cask->nit();

  # received shipments
  $self->{stock}=[];

  # scheduled tasks
  $self->{orders}=[];

  $self->{idex}=$frame->{harbors}->give($self);
  $self->{name}.='>>:harbor_'.$self->{idex};

  return $self;

};

# ---   *   ---   *   ---
# adds target to trade routes

sub open_route($self,$path) {

  my $dst=$self->get_sock(

    Type=>SOCK_STREAM(),
    Peer=>$path,

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
