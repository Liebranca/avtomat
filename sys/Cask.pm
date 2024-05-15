#!/usr/bin/perl
# ---   *   ---   *   ---
# Cask
# Array that reuses vacant slots
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Cask;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::IO;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(
    $FIRST_VALUE
    $FIRST_AVAIL

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v1.00.7;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $SENTINEL    => [0x5E4714E7];

  Readonly our $FIRST_VALUE => [0xCA547A4E];
  Readonly our $FIRST_AVAIL => [0xCA5461BE];

# ---   *   ---   *   ---
# cstruc

sub new($class,@data) {

  my $i=0;
  return bless [map {$i++=>$ARG} @data],$class;

};

# ---   *   ---   *   ---
# get non-deleted values

sub value($self) {

  return grep {
     defined $ARG
  && $ARG ne $SENTINEL

  } array_values($self);

};

# ---   *   ---   *   ---
# ^get free slots

sub avail($self) {

  return grep {
   ! defined $ARG
  || $ARG eq $SENTINEL

  } array_values($self);

};

# ---   *   ---   *   ---
# ^first non-deleted

sub first_value($self) {
  return ($self->value())[0];

};

# ---   *   ---   *   ---
# ^first deleted

sub first_avail($self) {
  return ($self->avail())[0];

};

# ---   *   ---   *   ---
# replace avail slot or
# push new one

sub give($self,$value) {

  my %h     = reverse @$self;
  my $avail = $h{$SENTINEL};


  # ^push new if none avail
  if(! defined $avail) {
    $avail=@$self >> 1;
    push @$self,$avail=>$value;

  # ^reuse free slot
  } else {
    $self->[($avail << 1)+1]=$value;

  };


  return $avail;

};

# ---   *   ---   *   ---
# give if value missing
# else do nothing ;>

sub cgive($self,$value) {

  my $idex=$self->has($value);

  return (! defined $idex)
    ? (0,$self->give($value))
    : (1,$idex)
    ;

};

# ---   *   ---   *   ---
# get un-adjusted idex into array

sub iof($self,$lkup=$FIRST_AVAIL) {

  my $out=undef;
  return $out if ! defined $lkup;


  # get idex of non-deleted slot
  if($lkup eq $FIRST_VALUE) {
    $out=$self->first_value();

  # ^get idex of free slot
  } elsif($lkup eq $FIRST_AVAIL) {
    $out=$self->first_avail();


  # ^get by value or numerical idex
  } else {

    my %h=map {
      (! defined $ARG) ? 'undef' : $ARG ;

    } reverse @$self;

    $out=(! ($lkup=~ $NUM_RE))

      ? $h{$lkup}

      : (defined $self->[$lkup << 1])
        ? $lkup : undef

      ;

  };

  return $out;

};

# ---   *   ---   *   ---
# give idex if value present
# undef on missing

sub has($self,$value) {

  my %h=map {
    (! defined $ARG) ? 'undef' : $ARG ;

  } reverse @$self;

  return $h{$value};

};

# ---   *   ---   *   ---
# ^apply adjustment

sub iofa($self,$lkup=$FIRST_AVAIL) {

  my $idex=$self->iof($lkup);

  return (defined $idex)
    ? ($idex << 1)+1
    : $idex
    ;

};

# ---   *   ---   *   ---
# get value and replace

sub take($self,%O) {

  # defaults
  $O{idex} //= $FIRST_VALUE;
  $O{repl} //= $SENTINEL;


  # get idex
  my $out  = undef;
  my $idex = $self->iofa($O{idex});

  defined $idex or throw_empty();


  # ^replace and give old
  $out           = $self->[$idex];
  $self->[$idex] = $O{repl};

  return $out;

};

# ---   *   ---   *   ---
# ^errmes

sub throw_empty() {

  errcaller();
  errout(
    q[Take from empty cask],
    lvl=>$AR_FATAL,

  );

};

# ---   *   ---   *   ---
# ^just get value

sub view($self,$idex=$FIRST_AVAIL) {

  my $i=$self->iofa($idex);
  return (defined $i) ? $self->[$i] : undef ;

};

# ---   *   ---   *   ---
# array depleted

sub empty($self) {
  my $x=int $self->avail();
  return $x == (int @$self) >> 1;

};

# ---   *   ---   *   ---
# ^array has no free slots

sub full($self) {
  my $x=int $self->value();
  return $x == (int @$self) >> 1;

};

# ---   *   ---   *   ---
1; # ret
