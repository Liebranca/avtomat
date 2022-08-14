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

  use Type;
  use Blk;

  use Shb7;

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

    # path to ctlproc socket
    net=>$NULLSTR,

    # instance containers
    harbors=>Cask->nit(),
    vessels=>Cask->nit(),

  }};

  Readonly our $UNLOCK=>'RTMAX';

# ---   *   ---   *   ---

  Readonly our $NET_SIGIL=>q[@];
  Readonly our $NET_RS=>q[:];

  Readonly our $MESS_ST=>$Type::Table->nit(

    'pesonet_header',[

      byte=>'sigil',
      byte_str=>'dom(7)',
      byte_str=>'id(32)',

      word=>'src,dst,size',

    ],

  );

# ---   *   ---   *   ---
# RPC table

  Readonly our $REQTAB=>[

    $NET_SIGIL.q[nit]=>q[nit],
    $NET_SIGIL.q[gpr]=>q[get_peer],
    $NET_SIGIL.q[snk]=>q[sink],

  ];

# ---   *   ---   *   ---
# global state

  our $Blk_F=Blk->new_frame();
  our $Non=$Blk_F->nit(undef,'non');

  our $Mess_Pool;

INIT {

  my $ptr=$Non->alloc(
    '@pesonet<Mess_Pool>',

    $MESS_ST,64

  );

  $Mess_Pool=Cask->nit(@{$ptr->buf()});

};

# ---   *   ---   *   ---
# destructor

sub DESTROY($self) {

  # remove file
  if(-e $self->{path}) {
    unlink $self->{path};

  };

  if(defined $self->{sock}) {
    $self->{sock}->close();

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
    sock=>undef,

    frame=>$frame,

  },$class;

  # first instance assumes the role of master
  if($frame->{net} eq $NULLSTR) {
    $frame->{net}=$via->{path};
    $frame->{name}=$name;

  };

  if(-e $via->{path}) {unlink $via->{path}};
  return $via;

};

sub open($self,$qsz=1) {

  $self->{sock}=$self->get_sock(

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

  my $header=$NULLSTR;
  $dst->recv($header,$MESS_ST->{size});

  $header=$MESS_ST->decode($header);

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

  while(my $ship=$self->{sock}->accept) {

    # get shipment
    my $pkg=$NULLSTR;
    $ship->recv($pkg,$MESS_ST->{size});

    say "received $pkg";
    my ($op,$class,@args)=split $SPACE_RE,$pkg;

    my $header=$Mess_Pool->take();

    # fetch from request table
    if(exists $req{$op}) {

      $op=$req{$op};

      $class=$frame->{-class}.q{::}.$class;
      unshift @args,$frame;

      my $x=$class->$op(@args);


      if(length ref $x) {

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

    # is this bit necessary?
    # the docs are confusing about it
    $ship->close();

    last if($self->{frame}->{harbors}->empty());

  };

};

# ---   *   ---   *   ---
# gets new instance from ctlproc

sub new_harbor($class,$name) {

  my $path=$Shb7::Mem;

  my $via=Via->ship(

    "$path$name.sock",

    $NET_SIGIL."nit Harbor $name$NET_RS$0"

  );

  return $via;

};

# ---   *   ---   *   ---
# ^same, existing instance

sub get_harbor($self,$name,$idex=0) {

  my $via=Via->ship(

    $self->{net},
    $NET_SIGIL."gpr Harbor $name $idex"

  );

  return $via;

};

# ---   *   ---   *   ---
1; # ret
