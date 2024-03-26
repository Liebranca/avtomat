#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX
# Slow runner ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::lx;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Re;
  use Arstd::PM;
  use Arstd::IO;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    main  => undef,

    links => [],
    queue => [],

  },

  stages=>[qw(parse solve xlate run)],

};

# ---   *   ---   *   ---
# reset per-expression state

sub exprbeg($self,$rec=0) {

  # get ctx
  my $Q     = $self->{queue};
  my $have  = $self->{links};

  my $ahead = [];


  # preserve current?
  if($rec > 0) {
    push @$Q,$have;

  # ^restore previous?
  } else {
    $ahead   = pop @$Q;
    $ahead //= [];

  };


  # set or clear state
  @$have=@$ahead;

};

# ---   *   ---   *   ---
# records sub-expression result

sub exprlink($self,$have) {

  my $main  = $self->{main};
  my $links = $self->{links};

  if(defined $have) {
    push @$links,$have;
    return $have;

  } else {
    return;

  };

};

# ---   *   ---   *   ---
# get name of current rd/ipret step

sub stagename($self) {

  return $self->stages()->[
    $self->{main}->{stage}

  ];

};

# ---   *   ---   *   ---
# generate/fetch command table

sub load_CMD($self,$update=0) {


  # get ctx
  my $main   = $self->{main};
  my $cmdlib = $main->{cmdlib};

  # skip update?
  my $tab=$cmdlib->{icetab};

  return $cmdlib
  if exists $cmdlib->{-re} &&! $update;

  # ^nope, regen!
  my @keys=keys %$tab;

  delete $cmdlib->{-re};
  $cmdlib->{-re}=re_eiths(

    \@keys,

    opscape => 1,
    bwrap   => 1,
    whole   => 1,

  );


  return $cmdlib;

};

# ---   *   ---   *   ---
1; # ret
