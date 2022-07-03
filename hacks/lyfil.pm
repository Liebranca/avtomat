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
package lyfil;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use style;
  use arstd;

# ---   *   ---   *   ---
# info

  our $VERSION=0.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# global state

  my $M=[];
  my $ACTIVE={};

# ---   *   ---   *   ---

sub nit($fname,$beg) {

  my $class=(caller)[0];
  my $self=bless {

    id=>$class,

    fname=>$fname,
    chain=>$M,
    idex=>int(@{$M}),

    data=>[],
    raw=>NULLSTR,

    lineno=>$beg,

    beg=>qr{(?<!#)use $class},
    end=>qr{(?<!#)no $class},

  },$class;

  if(

    $M->[0] && $M->[0]->{fname} ne $self->{fname}

  ) {return NULL};

print {*STDERR} "**** $class\n";

  $ACTIVE->{$class}=$self;
  if($M->[0]) {$self->pluck_use_line()};

  push @$M,$self;
  return $self;

};

# ---   *   ---   *   ---

sub del($self) {

  $self->pluck_use_line();
  $self->code_emit();

  arstd::arrshf($M,$self->{idex});
  delete $ACTIVE->{$self->{id}};

};

# ---   *   ---   *   ---

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

#  if(!$out) {
#    $$stringref=q{};
#
#  };

  return $out;

};

# ---   *   ---   *   ---

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

sub prich($self,%opt) {

  # opt defaults
  $opt{errout}//=0;

  # select filehandle
  my $FH=($opt{errout}) ? *STDERR : *STDOUT;

# ---   *   ---   *   ---

  return print {$FH} $self->{raw};

};

# ---   *   ---   *   ---
1; # ret
