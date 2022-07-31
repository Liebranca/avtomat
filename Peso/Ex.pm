#!/usr/bin/perl
# ---   *   ---   *   ---
# EX
# Holds processed blocktrees
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Peso::Ex;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/sys';

  use Style;
  use Arstd;

  use Peso::Node;
  use Peso::Blk;
  use Peso::Sbl;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.50.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# global kick

sub nit($class,$lang) {

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

  },$class;

  $self->{ptr}=Peso::Ptr->new_frame($self);
  $self->{blk}=Peso::Blk->new_frame($self);

  $self->{node}=Peso::Node->new_frame($self);
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
# peso struct stuff

sub reg($self,$name,@entries) {

  my $bframe=$self->{blk};
  my $types=$self->{lang}->{types};

  # get clan or non
  my $dst=($bframe->{dst}->{attrs})
  ? $bframe->{dst}->{parent}
  : $bframe->{dst}
  ;

  # make new block
  my $blk=$bframe->nit($dst,$name,$O_RD|$O_WR);

# ---   *   ---   *   ---
# push values to block

  for my $entry(@entries) {
    my ($type,$attrs,$data)=@$entry;

    $blk->expand(

      $data,

      type=>$type,
      attrs=>$attrs,

    );

  };

};

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
