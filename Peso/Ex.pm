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
  use Frame;

  use Tree::Syntax;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Peso::Blk;
  use Peso::Ptr;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.50.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# global kick

sub nit($class,$lang) {

  my $self=bless {

    nxins=>0,
    pass=>0,

    lang=>$lang,
    tree=>undef,

    mem=>[],

    ptr=>undef,
    blk=>undef,

    node=>undef,

  },$class;

# ---   *   ---   *   ---

  $self->{ptr}=
    Peso::Ptr->new_frame($self->{mem});

  $self->{blk}=
    Peso::Blk->new_frame($self->{mem});

  $self->declscope('non',0);

#  $self->{node}=
#    Tree::Syntax->new_frame($lang);

  return $self;

};

# ---   *   ---   *   ---
# declare an empty block

sub declscope($self,$name,$idex) {

  $self->{scopes}->{$name}={

    # we use these values to navigate
    # pointer arrays through next/prev

    _beg=>$idex,
    _end=>$idex+1,

    _itab=>[],

  };

  return;

};

# ---   *   ---   *   ---
# getters/setters

sub fpass($self) {return $self->{pass}==0};

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
