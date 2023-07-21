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
  use Strtab;

  use Arstd::Array;

  use Type;
  use Mem;

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

  Readonly our $QUEUE_SIZE=>1;

  Readonly our $NET_SIGIL=>ord(q[@]);
  Readonly our $NET_RS=>q[:];

  Readonly our $SIGIL => $NET_SIGIL;
  Readonly our $DOM   => 0x5C24;

  Readonly our $MESS_ST=>$Type::Table->nit(

    'pesonet_me_header',[

      wide=>'sigil',
      wide=>'class',

      brad=>'fn_key',

      word=>'src,dst,size',

    ],

  );

# ---   *   ---   *   ---
# RPC table

  Readonly our $REQTAB=>Strtab->nit(qw(

    nit get_peer sink

  ));

  Readonly our $KLSTAB=>Strtab->nit(qw(

    Via Via::Harbor

  ));

# ---   *   ---   *   ---
# global state

  our $Mem_F     = Mem->new_frame();
  our $Non       = $Mem_F->nit(undef,'non');

  my  $Mess_PTR  = $Non->alloc(
    '@pesonet<Mess_Pool>',

    $MESS_ST,$QUEUE_SIZE

  );

  our $Mess_Pool = Cask->nit($Mess_PTR->subdiv());

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
    idex=>0,

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

sub open($self) {

  $self->{sock}=$self->get_sock(

    Type=>SOCK_STREAM(),
    Local=>$self->{path},
    Listen=>$QUEUE_SIZE,

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

sub ship($self,$path,%O) {

  my $out=$NULLSTR;
  my $dst=$self->get_sock(

    Type=>SOCK_STREAM(),
    Peer=>$path,

  );

  $O{args}//=$NULLSTR;
  my $pkg=join q{ },@{$O{args}};

  delete $O{args};

  # get struct from pool
  my $me=$Mess_Pool->take();
  my $me_attrs=$me->{by_name}->[0];

  $O{size}=length $pkg;
  $O{src}=(ref $self)
    ? $self->{idex}
    : 0
    ;

  $me->encode(%O);

  $dst->send($me->rawdata().$pkg);
  $dst->shutdown(SHUT_WR);

  $Mess_Pool->give($me);

  # get response
  my $hed=$NULLSTR;
  $dst->recv($hed,$MESS_ST->{size});
  $hed={@{$MESS_ST->decode($hed)}};

  # handle object returns
  $dst->recv($pkg,$hed->{size});
  if($hed->{class}) {
    $out=thaw($pkg);

  # plain value/no return
  } else {
    $out=$pkg;

  };

  say "arrived!";

  $dst->close();

  return $out;

};

# ---   *   ---   *   ---

sub arrivals($self) {

  my $frame=$self->{frame};

  while(my $ship=$self->{sock}->accept) {

    # read package header
    my $hed=$NULLSTR;
    $ship->recv($hed,$MESS_ST->{size});

    $hed={@{$MESS_ST->decode($hed)}};

    my ($fn_key,$class)=(
      $REQTAB->{name}->{$hed->{fn_key}},
      $KLSTAB->{name}->{$hed->{class}},

    );

    # read package contents
    my $pkg=$NULLSTR;
    $ship->recv($pkg,$hed->{size});

    say "received $class->$fn_key $pkg";
    my @args=split $SPACE_RE,$pkg;

    my $me=$Mess_Pool->take();
    my $me_attrs={};

    $me_attrs->{sigil}=$hed->{sigil};

# ---   *   ---   *   ---
# fetch from request table

    if(defined $fn_key) {

      unshift @args,$frame;

      my $ret=$class->$fn_key(@args);

# ---   *   ---   *   ---

      if(length ref $ret) {

        $me_attrs->{class}=0x01;

        my $restore=0;
        if(exists $ret->{frame}) {
          $ret->{frame}=undef;
          $restore=1;

        };

        $pkg=nfreeze($ret);
        $ret->{frame}=$frame if $restore;

# ---   *   ---   *   ---

      } else {

        $me_attrs->{class}=0x00;
        $pkg=$ret;

      };

    };

    $me_attrs->{size}=length $pkg;

# ---   *   ---   *   ---
# send response

    $me->encode(%$me_attrs);
    $ship->send($me->rawdata().$pkg);

    # notify
    $ship->shutdown(SHUT_RDWR);

    # give struct back to pool
    $me->flood(0);
    $Mess_Pool->give($me);

    last if($self->{frame}->{harbors}->empty());

  };

};

# ---   *   ---   *   ---

sub request($class,$dst,$fn_key,@args) {

  if(length ref $class) {
    $class=ref $class;

  };

  $class=~ s[::Remote::][::];

  return (

    sigil=>$NET_SIGIL,

    fn_key=>$REQTAB->{idex}->{$fn_key},
    class=>$KLSTAB->{idex}->{$class},

    dst=>$dst,

    args=>[@args],

  );

};

# ---   *   ---   *   ---
1; # ret
