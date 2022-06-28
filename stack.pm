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
  for my $i($sz-1..0) {
    push @$buf,$i;

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

sub gtop($self) {return $self->{top}};
sub top_plus($self) {return $self->{top}++};
sub top_mins($self) {return $self->{top}--};

sub gbuf($self) {return $self->{buf};};

# ---   *   ---   *   ---

sub spush($self,$value) {
  my $top=$self->gtop;
  $self->gbuf->[$top]=$value;
  $self->top_plus;

  return;

};sub spop($self) {
  $self->top_mins;
  my $top=$self->gtop;

  return $self->gbuf->[$top];

};

# ---   *   ---   *   ---
1; # ret
