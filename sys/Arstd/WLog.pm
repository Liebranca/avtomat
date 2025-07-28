#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD WLOG
# Cute echoes
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::WLog;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

  use Arstd::String;
  use Arstd::IO;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($WLog);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.6';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

St::vconst {
  LINE_BEG  => ansim('::','op'),
  EXE       => ansim('*:','op'),
  DOPEN     => ansim('>>','op'),
  DCLOSE    => ansim('<<','op'),

  ARTAG_OK  => strtag('AR',0),
  ARTAG_ERR => strtag('AR',1),

};


# ---   *   ---   *   ---
# GBL

  our $WLog=undef;


# ---   *   ---   *   ---
# cstruc

sub new($class) {

  my $self=bless {

    lvl  => 0,
    chld => [],

  },$class;

  return $self;

};


# ---   *   ---   *   ---
# ^fetch root

sub genesis($class) {

  $WLog=(! defined $WLog)
    ? $class->new()
    : $WLog
    ;

  return $WLog;

};


# ---   *   ---   *   ---
# outs to term

sub line($self,$s=null,$err=0) {

  my $fh=($err)
    ? *STDERR
    : *STDOUT
    ;

  my $pad=q[  ] x $self->{lvl};
  say {$fh} "$pad$s";

};


# ---   *   ---   *   ---
# notify of updated file

sub fupdate($self,$name,$me='updated') {
  my $s="$me " . ansim($name,'update');
  $self->line($self->LINE_BEG . $s,1);

};


# ---   *   ---   *   ---
# notify of on-going module update

sub mupdate($self,$name,$me='upgrading') {
  my $s="$me " . ansim($name,'update');
  $self->line($self->ARTAG_OK . $s,1);

};


# ---   *   ---   *   ---
# notify of module taking an action

sub mprich($self,$name,$act) {
  my $s=strtag($name,0) . $act;
  $self->line($s,1);

};

# ---   *   ---   *   ---
# notify of bin being run

sub ex($self,$name,$me=null) {
  $me=(length $me) ? "$me " : $me;

  my $s=$me . ansim($name,'ex');
  $self->line($self->EXE . $s,1);

};

# ---   *   ---   *   ---
# generic message

sub step($self,$me) {
  $self->line($self->LINE_BEG . $me,1);

};

sub substep($self,$me) {
  my $pad=q[  ] x ($self->{lvl}+1);
  $self->line($pad . $me,1);

};

# ---   *   ---   *   ---
# report error

sub err($self,$me,%O) {

  # defaults
  $O{details} //= null;
  $O{from}    //= 'AR';
  $O{lvl}     //= $AR_WARNING;
  $O{args}    //= [];


  # fit long message into screen
  $me=fstrout(
    strtag($O{from},1) . " $me",
    null,

    args     => $O{args},
    no_print => 1,

  );

  my @me   = split $NEWLINE_RE,$me;
  my $head = shift @me;

  $self->line("\n$head",1);

  map {$self->step($ARG)} @me;
  say null;


  # give backtrace?
  errout(
    $O{details},
    lvl=>$O{lvl}

  ) if $O{details};

  # exit without errout?
  exit -1 if $O{lvl} eq $AR_FATAL;


};


# ---   *   ---   *   ---
# make logtree root

{

  # we don't care if it's too late
  no warnings;

  INIT {
    Arstd::WLog->genesis();

  };

};


# ---   *   ---   *   ---
1; # ret
