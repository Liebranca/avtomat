#!/usr/bin/perl
# ---   *   ---   *   ---
# TOKEN
# Halfway mimics p6's
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Tree::Token;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use parent 'Tree';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,%O) {

  my $self=Tree::nit(

    $class,
    $frame,

    $O{parent},
    $O{value},

    %O

  );

  $self->{action}=$O{action};

  return $self;

};

# ---   *   ---   *   ---
# clones a node

sub dup($self) {

  my $cpy=$self->{frame}->nit(

    value  => $self->{value},
    action => $self->{action},

    parent => undef,

  );

  return $cpy;

};

# ---   *   ---   *   ---
# rewind the tree match

sub rew($st) {

  unshift

    @{$st->{pending}},
    $st->{nd}->{parent}

  ;

};

# ---   *   ---   *   ---
# saves capture to current container

sub push_to_anchor($st) {

  $st->{frame}->nit(
    $st->{anchor},$st->{capt}

  );

};

# ---   *   ---   *   ---
# terminates an expression

sub term($st) {

  $st->{anchor}     = $st->{nd}->walkup();
  $st->{expr}       = undef;

  @{$st->{pending}} = @{$st->{anchor}->{leaves}};

};

# ---   *   ---   *   ---
# makes helper for match

sub match_st($self) {

  my $frame = Tree->get_frame();
  my $root  = $frame->nit(

    undef,
    $self->{value}

  );

# ---   *   ---   *   ---

  my $st=bless {

    root    => $root,
    anchor  => $root,
    expr    => undef,

    capt    => q[],
    nd      => undef,

    frame   => $frame,
    pending => [@{$self->{leaves}}],

    re      => undef,
    key     => undef,

  },'Tree::Token::Matcher';

  return $st;

};

# ---   *   ---   *   ---
# decon string by walking tree branch

sub match($self,$s) {

  my $st=$self->match_st();

  while(@{$st->{pending}}) {

    last if !length $s;

    $st->get_next();
    $st->attempt(\$s);

    unshift

      @{$st->{pending}},
      @{$st->{nd}->{leaves}}

    ;

  };

  return $st->{root};

};

# ---   *   ---   *   ---
# helper methods

package Tree::Token::Matcher;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

# ---   *   ---   *   ---

sub get_next($self) {

  $self->{nd}  = shift @{$self->{pending}};

  $self->{key} =
  $self->{re}  = $self->{nd}->{value};
  $self->{re}  = undef if !is_qre($self->{re});
  $self->{key} = undef if defined $self->{re};

};

# ---   *   ---   *   ---

sub attempt($self,$sref) {

  if($self->{re}) {
    $self->attempt_match($sref);

  } elsif($self->{key}) {
    $self->expand_tree();

  };

};

# ---   *   ---   *   ---

sub attempt_match($self,$sref) {

  my $out = 0;
  my $re  = $self->{re};

  $self->{capt}=${^CAPTURE[0]}
  if $$sref=~ s[^\s*($re)\s*][];

  goto TAIL if !defined $self->{capt};

  $out=1+int(defined $self->{nd}->{action});

  $self->{nd}->{action}->($self)
  if $out==2;

  $self->{capt}=undef;

TAIL:
  return $out;

};

# ---   *   ---   *   ---

sub expand_tree($self) {

  $self->{expr}=$self->{frame}->nit(
    $self->{root},q[$]

  ) if !defined $self->{expr};

  $self->{anchor}=$self->{frame}->nit(
    $self->{expr},$self->{key}

  ) unless(

     $self->{key}
  eq $self->{anchor}->{value}

  );

};

# ---   *   ---   *   ---
1; # ret
