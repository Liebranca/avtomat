#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M HIER
# Put it in context
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::hier;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';
  use Style;

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    node  => undef,

    type  => 'blk',
    hist  => {},
    shist => [],

    Q     => {

      early  => [],
      late   => [],

      ribbon => [],

    },

    var   => {
      -order => [],

    },

    mcid  => 0,
    mccls => null,

  },


  typetab => {

    proc => [qw(const readable executable)],

  },

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  $class->defnit(\%O);

  my $self  = bless \%O,$class;
  my $flags = $class->typetab->{$self->{type}};

  $self->set_uattrs(

    (defined $flags)
      ? @$flags
      : ()
      ,

  );


  return $self;

};

# ---   *   ---   *   ---
# make/fetch point in hist

sub timeline($self,$uid,$data=undef) {

  # get ctx
  my $mc   = $self->getmc();
  my $hist = $self->{hist};

  # fetch, (set)?, give
  my $out = \$hist->{$uid};

  $$out=$mc->hierstruc($data)
  if defined $data;

  return $$out;

};

# ---   *   ---   *   ---
# add attr to obj

sub addattr($self,$name,$value) {
  $self->{$name}=$value;
  return;

};

# ---   *   ---   *   ---
# add method to execution queue

sub enqueue($self,$name,@args) {
  push @{$self->{Q}->{$name}},\@args;
  return;

};

# ---   *   ---   *   ---
# sort nodes in history

sub sort_hist($self,$recalc=0) {


  # get ctx
  my $out = $self->{shist};
  my @uid = keys %{$self->{hist}};

  # skip if we don't need to recalculate
  my $ok=@$out == @uid;
  return $out if $ok &&! $recalc;


  # sort elements idex relative to root
  my $root = $self->{node};
  my @have = $root->find_uid(@uid);

  map {
    my $i=$ARG->relidex($root);
    $out->[$i]=$self->{hist}->{$ARG->{-uid}};

  } @have;


  # remove blanks and give
  @$out=grep {defined $ARG} @$out;
  return $out;

};

# ---   *   ---   *   ---
1; # ret
