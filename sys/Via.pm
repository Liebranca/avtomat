#!/usr/bin/perl
# ---   *   ---   *   ---
# VIA
# A data highway
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Via;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;

  use English qw(-no_match_vars);

  use IO::Socket::UNIX;
  use Time::HiRes qw(usleep);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    # base path used for domain sockets
    # later on we'll see about mmap'd files...
    host=>$ENV{'ARPATH'}.'/.mem/',

  }};

  our $UNLOCK='RTMAX';

  our $UNLOAD="\x{24}\x{17}";
  our $UNLOAD_RE=qr{\x24\x17$}x;

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,$name) {

  my $via=bless {

    name=>$name,
    path=>$frame->{host}."$name.sock",

    sock=>undef,
    pid=>undef,

    frame=>$frame,

  },$class;

  return $via;

};

# ---   *   ---   *   ---
# destructor

sub DESTROY($self) {

  if($self->{pid} && -e $self->{path}) {
    unlink $self->{path};
    say "$self->{name} sunk";

  } else {
    say "$self->{name} shut";

  };

};

# ---   *   ---   *   ---
# locks until signal arrives

sub wait_for($self,$sig) {

  my $block=1;
  $SIG{$sig}=sub {$block=0};

  while($block) {usleep(1000)};
  $SIG{$sig}='DEFAULT';

};

# ---   *   ---   *   ---

sub set_sock($self,%O) {

  $self->{sock}=IO::Socket::UNIX->new(%O)
  or croak strerr("via '$self->{name}'");

};

# ---   *   ---   *   ---
# off to sea

sub sail($self) {

  if(-e $self->{path}) {unlink $self->{path}};

  $self->{pid}=fork;

  croak strerr("via '$self->{name}'")
  unless defined $self->{pid};

# ---   *   ---   *   ---
# vessel

  if($self->{pid}) {

    $self->set_sock(

      Type=>SOCK_STREAM(),
      Local=>$self->{path},
      Listen=>1,

    );

    $self->{name}.='<<:vessel';
    kill $UNLOCK,$self->{pid};

# ---   *   ---   *   ---
# harbor

  } else {

    $self->wait_for($UNLOCK);
    $self->set_sock(

      Type=>SOCK_STREAM(),
      Peer=>$self->{path},

    );

    $self->{name}.=':>>harbor';

  };

  return $self->{pid};

};

# ---   *   ---   *   ---

sub arrival($self) {
  return $self->{sock}->accept();

};

sub shipments($self) {

  local $RS=$UNLOAD;
  my $harb=$self->{sock};

  my @crates=map {
    $ARG=~ s[$UNLOAD_RE][];$ARG

  } <$harb>;

  return @crates;

};



# ---   *   ---   *   ---
1; # ret
