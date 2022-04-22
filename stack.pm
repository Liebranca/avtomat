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

  use strict;
  use warnings;

# ---   *   ---   *   ---

sub slidex {

  my $sz=shift;

  my $buf=[];
  for(my $i=$sz-1;$i>-1;$i--) {
    push @$buf,$i;

  };return ($sz,$buf);

};

# ---   *   ---   *   ---

sub nit {

  my $top=shift;
  my $buf=shift;

  return bless(

    { -TOP=>$top,
      -BUF=>$buf,

    },"stack"

  );
};

# ---   *   ---   *   ---

sub top {return (shift)->{-TOP};};
sub top_plus {(shift)->{-TOP}++;};
sub top_mins {(shift)->{-TOP}--;};

sub buf {return (shift)->{-BUF};};

# ---   *   ---   *   ---

sub spush {

  my $self=shift;
  my $value=shift;

  my $top=$self->top;
  $self->buf->[$top]=$value;

  $self->top_plus;

};sub spop {

  my $self=shift;

  $self->top_mins;
  my $top=$self->top;

  return $self->buf->[$top];

};

# ---   *   ---   *   ---
1; # ret
