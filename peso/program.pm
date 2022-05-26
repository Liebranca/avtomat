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
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use peso::node;
  use peso::blk;
  use peso::sbl;

# ---   *   ---   *   ---
# getters

sub ptr {return (shift)->{-PTR};};
sub blk {return (shift)->{-BLK};};
sub node {return (shift)->{-NODE};};
sub lang {return (shift)->{-LANG};};

# ---   *   ---   *   ---
# global kick

sub nit($) {

  my ($lang)=@_;

  my $self=bless {

    -NXINS=>0,
    -NODES=>[],

    -LANG=>$lang,

  },'peso::program';

  $self->{-BLK}=peso::blk::new_frame($self);
  $self->{-PTR}=peso::ptr::new_frame($self);
  $self->{-NODE}=peso::node::new_frame($self);

  $self->nxins(0);

  return $self;

};

# ---   *   ---   *   ---
# getters/setters

sub nxins($;$) {

  my ($self,$new)=@_;
  if(defined $new) {
    $self->{-NXINS}=$new;

  };return $self->{-NXINS};

};sub incnxins($) {((shift)->{-NXINS})++;};

# ---   *   ---   *   ---
# save node/tree for later use

sub nodes($) {

  my ($self)=@_;
  return $self->{-NODES};

};

sub setnode($$) {

  my ($self,$node)=@_;

  push @{$self->nodes},$node;
  return int(@{$self->nodes})-1;

# ^get saved node from index
};sub getnode($$) {

  my ($self,$idex)=@_;
  return $self->nodes->[$idex];

};

# ---   *   ---   *   ---
# execute program as defined by blocks

sub run {

#  my $entry=peso::blk::entry;
#  my $non=peso::blk::NON;
#
#  peso::ptr::wed(undef);
#
#  # get entry point block
#  $entry=peso::ptr::fetch($entry)->blk;
#  setnxins($entry->insid);
#
#  # scope to block
#  peso::blk::setcurr($entry);
#  peso::blk::setscope($entry->scope);
#
#  # debug: print out what we're executing
#  printf "ex ".$entry->name."\n";
#
#  # execute until end
#  while(!(nxins()<0)) {
#    $entry=exnext($entry);
#
#    if(nxins()<0) {last;};
#
#  };

};

# ---   *   ---   *   ---
# get next instruction

sub next_ins {

#  my $blk=shift;
#  my $i=nxins();
#
#  if($i<0) {return (undef,undef,undef);};
#
#  my $nx=sprintf "_%.08i",$i;
#
#  my $ins='ins'.$nx;
#  my $arg='arg'.$nx;
#
## ---   *   ---   *   ---
## when instruction not found in current,
## find block matching instruction index
#
#  if(!exists $blk->elems->{$ins}) {
#    $blk=getinsid($i);
#
#  };
#
#  return ($blk,$ins,$arg);

# ---   *   ---   *   ---
# get instruction matching index

};sub getinsid {

#  my $i=shift;
#  my $blk=peso::blk::INS->[$i];
#
#  # scope to block
#  peso::blk::setcurr($blk);
#  peso::blk::setscope($blk->scope);
#
#  # debug: print out what we're executing
#  printf "ex ".$blk->name."\n";
#
## ---   *   ---   *   ---
## catch: no instruction matches index
#
#  if(!defined $blk) {
#
#    printf "EX_END: instruction fetch fail!\n";
#    exit;
#
#  };return $blk;

};

# ---   *   ---   *   ---
# execute next instruction in stack

sub exnext {

#  my $blk=shift;
#  my ($ins,$arg)=(0,0);
#
#  # get idex of instruction
#  my $i=nxins();
#
#  # fetch instruction matching idex
#  ($blk,$ins,$arg)=next_ins($blk);
#  if(!defined $blk) {return;};
#
## ---   *   ---   *   ---
## decode instruction/argument ptrs
#
#  $ins=$blk->getv($ins);
#  $arg=$blk->getv($arg);
#
#  # duplicate node containing args
#  $arg=getnode($arg);
#  my $ori=$arg;
#  $arg=$arg->dup();
#
#  # execute instruction
#  peso::defs::INS->[$ins]->ex($arg);
#
#  # increase stack ptr if !jmp
#  if($i == nxins()) {incnxins();};
#  return $blk;

};

# ---   *   ---   *   ---
1; # ret
