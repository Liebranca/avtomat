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

    'pesonet_me_header',[

      byte=>'sigil',
      byte_str=>'fn_key(7)',
      byte_str=>'class(32)',

      word=>'src,dst,size',

    ],

  );

# ---   *   ---   *   ---
# RPC table

  Readonly our $REQTAB=>[

    q[nit]=>q[nit],
    q[gtpe]=>q[get_peer],
    q[sink]=>q[sink],

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

  $Mess_Pool=Cask->nit($ptr->subdiv());

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

  # get response
  my $hed=$NULLSTR;
  $dst->recv($hed,$MESS_ST->{size});
  $hed={@{$MESS_ST->decode($hed)}};

  # handle object returns
  $dst->recv($pkg,$hed->{size});
  if($hed->{fn_key} eq 'obj') {
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

  my %req=@$REQTAB;
  my $frame=$self->{frame};

  while(my $ship=$self->{sock}->accept) {

    # read package header
    my $hed=$NULLSTR;
    $ship->recv($hed,$MESS_ST->{size});

    $hed={@{$MESS_ST->decode($hed)}};

    my ($fn_key,$class)=(
      $hed->{fn_key},
      $hed->{class},

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

    if(exists $req{$fn_key}) {

      my $op=$req{$fn_key};
      unshift @args,$frame;

      my $ret=$class->$op(@args);

# ---   *   ---   *   ---

      if(length ref $ret) {

        $me_attrs->{fn_key}='obj';

        my $restore=0;
        if(exists $ret->{frame}) {
          $ret->{frame}=undef;
          $restore=1;

        };

        $pkg=nfreeze($ret);
        $ret->{frame}=$frame if $restore;

# ---   *   ---   *   ---

      } else {

        $me_attrs->{fn_key}='ret';
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
# gets new instance from ctlproc

sub new_harbor($class,$name) {

  my $path=$Shb7::Mem;

  my $via=Via->ship(

    "$path$name.sock",

    sigil=>$NET_SIGIL,
    fn_key=>'nit',
    class=>'Via::Harbor',

    dst=>0,

    args=>["$name$NET_RS$0"],

  );

  return $via;

};

# ---   *   ---   *   ---
# ^same, existing instance

sub get_harbor($self,$name,$idex=1) {

  my $via=Via->ship(

    $self->{net},

    sigil=>$NET_SIGIL,
    fn_key=>'gtpe',
    class=>'Via::Harbor',

    dst=>0,

    args=>[$name,$idex],

  );

  return $via;

};

# ---   *   ---   *   ---
1; # ret
