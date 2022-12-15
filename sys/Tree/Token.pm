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

  # defaults
  $O{parent}//=undef;
  $O{action}//=undef;

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
# rewind the tree match

sub rew(

  $capt,

  $nd,

  $anchor,
  $pending

) {

  unshift @$pending,$nd->{parent};

};

# ---   *   ---   *   ---
# saves capture to current container

sub push_to_anchor(

  $capt,

  $nd,

  $anchor,
  $pending

) {

  push @$anchor,$capt;

};

# ---   *   ---   *   ---
# decon string by walking tree branch

sub match($self,$s) {

  my @pending = ($self);

  my $result  = [];
  my $anchor  = undef;

# ---   *   ---   *   ---

  while(@pending) {

    my $nd    = shift @pending;
    my $re    = $nd->{value};

    my $valid = is_qre($re);

# ---   *   ---   *   ---

    if($valid && $s=~ s[^\s*($re)\s*][]) {

      $nd->{action}->(

        ${^CAPTURE[0]},

        $nd,

        $anchor,
        \@pending

      ) if $nd->{action};

# ---   *   ---   *   ---

    } elsif(!$valid && !($re=~ m[<])) {

      if(!defined $anchor) {

        push @$result,[$re];
        $anchor=$result->[-1];

      };

    };

# ---   *   ---   *   ---

    unshift @pending,@{$nd->{leaves}};

  };

# ---   *   ---   *   ---

  for my $entry(@$result) {

    my $key=shift @$entry;
    $entry={$key=>$entry};

  };

  return $result;

};

# ---   *   ---   *   ---
1; # ret
