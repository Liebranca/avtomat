#!/usr/bin/perl
# ---   *   ---   *   ---
# LYPERL
# Makes Perl even cooler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package lyperl;
  use strict;
  use warnings;

  use Filter::Util::Call;

  use lib $ENV{'ARPATH'}.'/avtomat/';
  use lang;

# ---   *   ---   *   ---

sub import {

  my ($type)=@_;
  my ($ref)={

    lline_exp=>0,

    line=>'',
    lineno=>1,

    macros=>{},

    unpro=>[],
    exps=>[],

  };filter_add(bless $ref);

};

# ---   *   ---   *   ---

sub mangle($$) {

  my $self=shift;
  my $s=shift;

  my $matches=lang::mcut(

    $s,

    'DQ'=>lang::dqstr,
    'SQ'=>lang::sqstr,
    'RE'=>lang::restr,

  );

  push @{$self->{unpro}},[$s,$matches];

};sub restore($) {

  my $self=shift;
  my @ar=@{$self->{unpro}};

  while(@ar) {

    my $ref=shift @ar;
    my $s=lang::mstitch($ref->[0],$ref->[1]);

    printf "$s";

  };

};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;
  my $status=filter_read();

  if(
      $status<=0
  ||  !length lang::stripline($_)
  || m/^\s*#/

  ) {

    if($status<=0) {
      $self->restore();

    };return $status;

  };my $s=$_;

# ---   *   ---   *   ---

  # not a multi-line bit
  if($self->{lline_exp}) {
    $self->{line}=$s;

  # the other way around
  } else {
    $self->{line}.=$s;

  };

# ---   *   ---   *   ---

  $self->mangle($s);$_='';
  $self->{lineno}++;

  return $status;

};

# ---   *   ---   *   ---
1; # ret

