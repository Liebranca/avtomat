#!/usr/bin/perl
# ---   *   ---   *   ---
# RD SIGTAB
# Tables of patterns...
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::sigtab;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT=>{

    main => undef,
    tab  => {},

    keyw => undef,

  },

  sig_t => 'rd::sig',

};

# ---   *   ---   *   ---
# get element

sub fetch($self,$keyw) {
  return $self->{tab}->{$keyw};

};

# ---   *   ---   *   ---
# ^get and validate!

sub valid_fetch($self,$keyw) {

  my $have=$self->fetch($keyw);
  my $main=$self->{main};

  $main->throw_undefined(
    'KEY',$keyw,'non','lx'

  ) if ! $have;


  return $have;

};

# ---   *   ---   *   ---
# make table entry

sub begin($self,$keyw) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # set as current
  $self->{keyw}=$keyw;

  # make new entry
  my $dst=$self->{tab}->{$keyw}={};

  $dst->{sig} = [];
  $dst->{fn}  = $NOOP;
  $dst->{re}  = $l1->re(SYM=>$keyw);

  return;

};

# ---   *   ---   *   ---
# pushes a new pattern array
# to table

sub pattern($self,@seq) {

  # get ctx
  my $keyw  = $self->{keyw};
  my $dst   = $self->{tab}->{$keyw};
  my $sig_t = $self->sig_t;

  # ^make new signature and push
  my $sig = $sig_t->new(\@seq);

  push @{$dst->{sig}},$sig;


  return;

};

# ---   *   ---   *   ---
# ^binds function to pattern array

sub function($self,$fn) {

  # get ctx
  my $keyw = $self->{keyw};
  my $dst  = $self->{tab}->{$keyw};

  # copy
  $dst->{fn} = $fn;

  return;

};

# ---   *   ---   *   ---
# merges data on current entry

sub build($self) {


  # get ctx
  my $keyw = $self->{keyw};
  my $dst  = $self->{tab}->{$keyw};
  my $ar   = $dst->{sig};


  # get first definition of default
  # value for attr, across all signatures
  my $defv={};
  map {$ARG->attrs_to_hash(defv=>$defv)} @$ar;

  # now add default value to signatures
  # that do not explicitly declare it!
  map {$ARG->hash_to_attrs(defv=>$defv)} @$ar;


  # blankout current
  $self->{keyw}=undef;
  return;

};

# ---   *   ---   *   ---
# match input against pattern array

sub match($self,$keyw,$x) {


  # get ctx
  my $tab   = $self->{tab};
  my $sigar = $tab->{$keyw}->{sig};


  # have signature match?
  my $data = {};

  for my $sig(@$sigar) {
    $data=$sig->match($x);
    last if length $data;

  };

  return $data;

};

# ---   *   ---   *   ---
1; # ret
