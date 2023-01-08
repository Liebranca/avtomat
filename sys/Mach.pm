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

  my $buff=\($self->{fd_buff}->[$dst]);
  $$buff.=$src;

};

sub reap($self,$dst) {

  my $buff=\($self->{fd_buff}->[$dst]);

  print {$self->{fd}->[$dst]} $$buff;

  $self->{fd}->[$dst]->flush();
  $$buff=$NULLSTR;

};

# ---   *   ---   *   ---
1; # ret
