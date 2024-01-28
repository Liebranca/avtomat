#!/usr/bin/perl
# ---   *   ---   *   ---
# LYFIL
# The master of filters
# not a filter itself
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Lyfil;

  use v5.36.0;
  use strict;
  use warnings;

  use Filter::Util::Call;

  use lib $ENV{'ARPATH'}.'/lib/sys';

  use Style;
  use Arstd::Array;

# ---   *   ---   *   ---
# info

  our $VERSION=0.00.3;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# global state

  my $M      = [];
  my $ACTIVE = {};

# ---   *   ---   *   ---
# cstruc

sub new($class,$fname,$beg) {

  my $self=bless {

    id      => $class,

    fname   => $fname,
    chain   => $M,
    idex    => int(@{$M}),

    data    => [],
    raw     => $NULLSTR,

    lineno  => $beg,

    beg     => qr{(?<!#)use $class},
    end     => qr{(?<!#)no $class},

  },$class;

  if(

     $M->[0]

  && $M->[0]->{fname}
  ne $self->{fname}

  ) {return $NULL};


  $ACTIVE->{$class}=$self;
  if($M->[0]) {$self->pluck_use_line()};

  push @$M,$self;
  return $self;

};

# ---   *   ---   *   ---
# remove self

sub del($self) {

  $self->pluck_use_line();
  $self->code_emit();

  array_lshift($M,$self->{idex});
  delete $ACTIVE->{$self->{id}};

};

# ---   *   ---   *   ---
# removes 'use' from file

sub pluck_use_line($self) {

  my $line=$self->{chain}->[0]->{data}->[-1];
  my $raw=\$self->{chain}->[0]->{raw};

  my ($beg,$end)=(
    $self->{beg},
    $self->{end},

  );

  $$raw=~ s/$beg//sg;
  $$raw=~ s/$end//sg;

};

# ---   *   ---   *   ---
# adds line to own buff

sub logline($self,$stringref) {

  my $out=int($self eq $self->{chain}->[-1]);
  if($out) {

    $self->{chain}->[0]
    ->{data}->[$self->{lineno}++]

    =

    $$stringref

    ;

    $self->{chain}->[0]->{raw}.=$$stringref;
    $out=1;

  };

  if($$stringref=~ $self->{end}) {$self->del()};

  return $out;

};

# ---   *   ---   *   ---
# executes children nodes

sub propagate($self) {

  if($self->{chain}) {

    my @ar=@{$self->{chain}};
    for my $f(@ar[1..$#ar]) {
      $f->code_emit();
      $f->del();

    };

  };

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%opt) {

  # opt defaults
  $opt{errout}//=0;

  # select filehandle
  my $FH=($opt{errout}) ? *STDERR : *STDOUT;


  return print {$FH} $self->{raw};

};

# ---   *   ---   *   ---
1; # ret
