#!/usr/bin/perl
# ---   *   ---   *   ---
# LOG
# it echoes!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Log;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);

  use Arstd::String qw(linewrap);
  use Arstd::ansi;
  use Arstd::throw;

  use St qw(is_valid);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.6';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM


sub step_prefix {
  return Arstd::ansi::mwrap('::','op');
};
sub exe_prefix {
  return Arstd::ansi::mwrap('*:','op');
};

sub dopen_prefix {
  return Arstd::ansi::mwrap('>>','op');
};

sub dclose_prefix {
  return Arstd::ansi::mwrap('<<','op');
};

sub tagok_prefix {
  $_[0] //= 'AR';
  return Arstd::ansi::mtag($_[0],'good');
};

sub tagerr_prefix {
  $_[0] //= 'AR';
  return Arstd::ansi::mtag($_[0],'err');
};


# ---   *   ---   *   ---
# cstruc/dstruc
#
# [*]: these are invoked directly __only__ when
#      you want to make a _sub_ log
#
#      for anything else, just use Log->F(...)

sub new {
  my $lvl=(! is_null(lvlcur()))
    ? lvlcur()->{lvl}+1
    : 0
    ;

  my $self=bless {
    lvl  => $lvl,
    chld => [],

  },__PACKAGE__;

  push @{lvlstk()},$self;
  return $self;
};

sub del {
  pop @{lvlstk()};
  return;
};


# ---   *   ---   *   ---
# subs to keep track of Log instances
#
# [*]: global state

sub lvlstk {
  state $stk=[];
  return $stk;
};

sub lvlcur {
  return lvlstk()->[-1];
};


# ---   *   ---   *   ---
# makes root if it doesn't exist

sub import {
  my ($class)=@_;
  my $log=(is_null(lvlcur()))
    ? $class->new()
    : lvlcur()
    ;

  return;
};


# ---   *   ---   *   ---
# converts class to self if need
#
# [0]: mem ptr ; ice | class
# [<]: mem ptr ; log instance

sub get_self {
  return $_[0] if $_[0]->is_valid($_[0]);
  return lvlcur();
};


# ---   *   ---   *   ---
# outs to term

sub line($class,$s=null,$err=0) {
  my $self = get_self($class);
  my $fh   = ($err)
    ? *STDERR
    : *STDOUT
    ;

  my $pad='  ' x $self->{lvl};
  say {$fh} "$pad$s";

  return;
};


# ---   *   ---   *   ---
# notify of updated file

sub fupdate($class,$name,$me='updated') {
  my $self = get_self($class);
  my $s    = "$me " . Arstd::ansi::m(
    $name,'update'
  );

  return $self->line(step_prefix() . $s,1);
};


# ---   *   ---   *   ---
# notify of on-going module update

sub mupdate($class,$name,$me='upgrading') {
  my $self = get_self($class);
  my $s    = "$me " . Arstd::ansi::m(
    $name,'update'
  );

  return $self->line(tagok_prefix() . $s,1);
};


# ---   *   ---   *   ---
# notify of module taking an action

sub mprich($class,$name,$act) {
  my $self = get_self($class);
  my $s    = tagok_prefix($name) . $act;

  return $self->line($s,1);
};

# ---   *   ---   *   ---
# notify of bin being run

sub ex($class,$name,$me=null) {
  my $self=get_self($class);
  $me=(length $me) ? "$me " : $me;

  my $s=$me . Arstd::ansi::mwrap($name,'ex');
  return $self->line(exe_prefix() . $s,1);
};

# ---   *   ---   *   ---
# generic message

sub step($class,$me) {
  my $self=get_self($class);
  return $self->line(step_prefix() . $me,1);
};

sub substep($class,$me) {
  my $self = get_self($class);
  my $pad  = '  ' x ($self->{lvl}+1);

  return $self->line($pad . $me,1);
};


# ---   *   ---   *   ---
# report error

sub err($class,$me,%O) {
  my $self=get_self($class);

  # defaults
  $O{bt}     //= 0;
  $O{from}   //= 'AR';
  $O{throw}  //= 0;
  $O{args}   //= [];

  # run sprintf?
  $me=sprintf($me,@{$O{args}})
  if @{$O{args}};

  # fit long message into screen
  $me=linewrap(
    tagerr_prefix($O{from}) . " $me"
  );

  my @me   = split qr"\n",$me;
  my $head = shift @me;

  $self->line("\n$head",1);

  map {$self->step($ARG)} @me;
  say null;


  # give backtrace?
  say {*STDERR} Arstd::throw::bt_repr()
  if $O{bt};

  # throw?
  throw if $O{throw};
  return;
};


# ---   *   ---   *   ---
1; # ret
