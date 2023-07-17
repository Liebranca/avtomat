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

  use Mach::Scope;
  use Mach::Value;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# GBL

  my $Icemap={};

# ---   *   ---   *   ---
# constructor

sub new($class,%O) {

  # defaults
  $O{gpr_cnt}  //= 16;
  $O{ret_idex} //= 0;
  $O{idex}     //= 0;

  $O{fd}       //= [*STDIN,*STDOUT,*STDERR];

  my $gpr={};
  for my $i(0..$O{gpr_cnt}-1) {
    $gpr->{"r$i"}=0;

  };

  my $fd_buff=[
    ($NULLSTR) x int(@{$O{fd}})

  ];

  my $frame = $class->get_frame($O{idex});

  my $self  = bless {

    gpr      => $gpr,
    ret_idex => "r$O{ret_idex}",

    stk      => [],
    stk_top  => 0,

    fd       => $O{fd},
    fd_buff  => $fd_buff,

    scope    => Mach::Scope->new(),

    frame    => $frame,

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# ^retrieve or make

sub fetch($class,$id,%O) {

  my $out=undef;

  # create and save
  if(! exists $Icemap->{$id}) {
    $out=$class->new(%O);
    $Icemap->{$id}=$out;

  # get existing
  } else {
    $out=$Icemap->{$id};

  };

  return $out;

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
# blank value

sub null($self,$type='void') {
  return $self->vice($type,raw=>$NULL);

};

# ---   *   ---   *   ---
# make unbound value ice

sub vice($self,$type,%O) {

  return Mach::Value->new(
    $type,$NULLSTR,%O

  );

};

# ---   *   ---   *   ---
# ^declare

sub decl($self,$type,$id,%O) {

  my @path  = decl_prologue(\%O);
  my $value = Mach::Value->new($type,$id,%O);

  my $ptr   = $value->bind($self->{scope},@path);

  return $ptr;

};

# ---   *   ---   *   ---
# ^shorthand for existing values

sub bind($self,$value,%O) {

  my @path = decl_prologue(\%O);
  my $ptr  = $value->bind($self->{scope},@path);

  return $ptr;

};

# ---   *   ---   *   ---
# ^alias

sub lis($self,$to,$from,%O) {

  $O{raw}=$from;

  my @path  = (decl_prologue(\%O),q[$LIS]);
  my $value = Mach::Value->new('lis',$to,%O);

  $value->bind($self->{scope},@path);

  return $value;

};

# ---   *   ---   *   ---
# ^common chore

sub decl_prologue($o) {

  # defaults
  $o->{path} //= [];

  # ^lis and pop
  my @path=@{$o->{path}};
  delete $o->{path};

  return @path;

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

# ---   *   ---   *   ---
# work out file descriptor
# from a relative ptr

sub fd_solve($self,$ptr) {

  # out
  my $fd;
  my $buff;

  # dst idex OK
  my $valid=defined $ptr
    && $ptr =~ m[^\d+$]
    && $ptr <  @{$self->{fd}}
    ;

  # attempt fetch on fail
  if(! $valid) {
    my @path=$self->{scope}->path();
    $buff=$self->{scope}->get(@path,$ptr);

  # get buff && descriptor
  } else {
    $fd   = $self->{fd}->[$ptr];
    $buff = \($self->{fd_buff}->[$ptr]);

  };

  return ($fd,$buff);

};

# ---   *   ---   *   ---
1; # ret
