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

  use Storable qw(nfreeze thaw);
  use English qw(-no_match_vars);

  use IO::Socket::UNIX;
  use Time::HiRes qw(usleep);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Cask;
  use Arstd::Array;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.3;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    # base path used for domain sockets
    # later on we'll see about mmap'd files...
    host=>$ENV{'ARPATH'}.'/.mem/',

    # instance containers
    harbors=>Cask->nit(),
    vessels=>Cask->nit(),

  }};

  our $UNLOCK='RTMAX';

  our $REQTAB=[

    q[@nit]=>q[nit],
    q[@snk]=>q[sink],

  ];

# ---   *   ---   *   ---
# destructor

sub DESTROY($self) {

  # remove file
  if(-e $self->{path}) {
    unlink $self->{path};

  };

  if(defined $self->{co}) {
    $self->{co}->close();

  };

  # announce shutdown
  # ... we should send actual ships to
  # the entire trade route later on
  if(defined $self->{frame}) {
    say {*STDERR} "$self->{name} sunk";

  };

};

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,$name) {

  my $via=bless {

    name=>$name,
    path=>$frame->{host}."$name.sock",

    pid=>undef,
    co=>undef,

    frame=>$frame,

  },$class;

  if(-e $via->{path}) {unlink $via->{path}};
  return $via;

};

sub open($self,$qsz=1) {

  $self->{co}=$self->get_sock(

    Type=>SOCK_STREAM(),
    Local=>$self->{path},
    Listen=>$qsz,

  );

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

sub get_sock($self,%O) {

  my $sock=IO::Socket::UNIX->new(%O)
  or croak strerr("via '$self->{path}'");

  return $sock;

};

# ---   *   ---   *   ---

sub split($self) {

  $self->{pid}=fork;

  croak strerr("via '$self->{name}'")
  unless defined $self->{pid};

  $self->{frame}=undef if !$self->{pid};

  return $self->{pid};

};

# ---   *   ---   *   ---

sub ship($self,$path,$pkg) {

  my $out=$NULLSTR;
  my $dst=$self->get_sock(

    Type=>SOCK_STREAM(),
    Peer=>$path,

  );

  $dst->send($pkg);
  $dst->shutdown(SHUT_WR);

  $dst->recv($pkg, 512);

  if($pkg ne 'ok') {
    $out=thaw($pkg);

  };

  say "arrived!";

  $dst->close();

  return $out;

};

# ---   *   ---   *   ---

sub arrivals($self) {


  my %req=@$REQTAB;

  my $frame=$self->{frame};

  while(my $ship=$self->{co}->accept) {

    # get shipment
    my $pkg=$NULLSTR;
    $ship->recv($pkg, 64);

    say "received $pkg";
    my ($op,$class,@args)=split $SPACE_RE,$pkg;

    # fetch from request table
    if(exists $req{$op}) {

      $op=$req{$op};

      $class=$frame->{-class}.q{::}.$class;
      unshift @args,$frame;

      my $x=$class->$op(@args);


      if($x) {

        my $restore=0;
        if(exists $x->{frame}) {
          $x->{frame}=undef;
          $restore=1;

        };

        $pkg=nfreeze($x);

        $x->{frame}=$frame if $restore;

      } else {
        $pkg='ok';

      };

    };

    # response
    $ship->send($pkg);

    # notify
    $ship->shutdown(SHUT_WR);

    last if($self->{frame}->{harbors}->empty());

  };

};

# ---   *   ---   *   ---
1; # ret
