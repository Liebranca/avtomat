#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH
# Barebones simulation
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::IO;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# global state

  my $TAB={};

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,%O) {

  # defaults
  $O{gpr_cnt}  //= 16;
  $O{ret_idex} //= 0;
  $O{fd}       //= [*STDIN,*STDOUT,*STDERR];

  my $gpr={};
  for my $i(0..$O{gpr_cnt}-1) {
    $gpr->{"r$i"}=0;

  };

  my $fd_buff=[
    ($NULLSTR) x int(@{$O{fd}})

  ];

  my $self=bless {

    gpr      => $gpr,
    ret_idex => "r$O{ret_idex}",

    stk      => [],
    stk_top  => 0,

    fd       => $O{fd},
    fd_buff  => $fd_buff,

    ctx      => $O{ctx},
    frame    => $frame,

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# stack control

sub stkpush($self,$x) {
  push @{$self->{stk}},$x;
  $self->{stk_top}++;

};

sub stkpop($self) {
  my $x=pop @{$self->{stk}};

  --$self->{stk_top} > -1
  or throw_stack_underflow();

  return $x;

};

# ---   *   ---   *   ---
# ^errmes

sub throw_stack_underflow() {

  errout(
    q[Stack underflow],
    lvl=>$AR_FATAL,

  );

};

# ---   *   ---   *   ---
# IO

sub sow($self,$dst,$src) {

  my ($fd,$buff)=$self->fd_solve($dst);
  $$buff.=$src;

};

sub reap($self,$dst) {

  my ($fd,$buff)=$self->fd_solve($dst);

  if(defined $fd) {
    print {$fd} $$buff;
    $fd->flush();

  };

  $$buff=$NULLSTR;

};

sub fd_solve($self,$dst) {

  # out
  my $fd;
  my $buff;

  # dst idex OK
  my $valid=defined $dst
    && $dst=~ m[^\d+$]
    && $dst<@{$self->{fd}}
    ;

  # attempt fetch on fail
  if(!$valid) {
    my $ctx  = $self->{ctx};
    my @path = $ctx->ns_path();

    $buff=$ctx->ns_fetch(@path,$dst);

  # get buff && descriptor
  } else {
    $fd   = $self->{fd}->[$dst];
    $buff = \($self->{fd_buff}->[$dst]);

  };

  return ($fd,$buff);

};

# ---   *   ---   *   ---
1; # ret
