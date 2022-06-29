#!/usr/bin/perl
# ---   *   ---   *   ---
# STACK
# last in, first out
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package stack;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# info

  our $VERSION=v1.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---

sub slidex($sz) {

  my $buf=[];
  for my $i(0..$sz-1) {
    push @$buf,$sz-1-$i;

  };

  return ($sz,$buf);

};

# ---   *   ---   *   ---

sub nit($top,$buf) {

  return bless {

    top=>$top,
    buf=>$buf,

  },'stack';

};

# ---   *   ---   *   ---

sub spush($self,$value) {
  $self->{buf}->[$self->{top}++]=$value;
  return;

};sub spop($self) {
  return $self->{buf}->[--$self->{top}];

};

# ---   *   ---   *   ---
1; # ret
