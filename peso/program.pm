#!/usr/bin/perl
# ---   *   ---   *   ---
# PROGRAM
# Runs a peso blocktree
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::program;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use peso::node;
  use peso::blk;
  use peso::sbl;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.4;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# getters

sub ptr($self) {return $self->{ptr};};
sub blk($self) {return $self->{blk};};
sub node($self) {return $self->{node};};
sub lang($self) {return $self->{lang};};

# ---   *   ---   *   ---
# global kick

sub nit($lang) {

  my $self=bless {

    nxins=>0,
    nodes=>[],

    lang=>$lang,
    run=>undef,

    pass=>0,

    tree=>undef,
    dst=>undef,

    defs=>{},
    refs=>{},

  },'peso::program';

  $self->{ptr}=peso::ptr::new_frame($self);
  $self->{blk}=peso::blk::new_frame($self);
  $self->{node}=peso::node::new_frame($self);

  $self->nxins(0);

  return $self;

};

# ---   *   ---   *   ---
# getters/setters

sub fpass($self) {return $self->{pass}==0};
sub incpass($self) {return $self->{pass}++};

sub nxins($self,$new=undef) {

  if(defined $new) {
    $self->{nxins}=$new;

  };return $self->{nxins};

};sub incnxins($self) {return $self->{nxins}++};

# ---   *   ---   *   ---
# placeholder

sub run($self,@args) {
  return $self->{run}->($self,@args);

};

sub set_entry($self,$coderef) {
  $self->{run}=$coderef;
  return;

};

# ---   *   ---   *   ---
1; # ret
