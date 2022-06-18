#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO
# $ syntax defs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package langdefs::peso;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
  use langdefs::plps;

  use peso::ops;
  use peso::defs;
  use peso::blk;

# ---   *   ---   *   ---
# leaps and such

use constant TYPE=>{

  # primitives
  'char'=>1,
  'wide'=>2,
  'word'=>4,
  'long'=>8,

# ---   *   ---   *   ---
# granularity

  # ptr size
  'unit'=>0x0008,

  # pointers align to line
  # mem buffers align to page

  'line'=>0x0010, # two units
  'page'=>0x1000, # 256 lines

# ---   *   ---   *   ---
# function types

  'nihil'=>8,     # void(*nihil)(void)
  'stark'=>8,     # void(*stark)(void*)

  'signal'=>8,    # int(*signal)(int)

# ---   *   ---   *   ---
# the 'make-a-var' call

  'value_decl'=>[sbl_id,'ptr_decl'],

};

# ---   *   ---   *   ---
# builtins and functions, group A

use constant BUILTIN=>{

  'cpy'=>[sbl_id,'2<ptr,ptr|bare>'],
  'mov'=>[sbl_id,'2<ptr,ptr>'],
  'wap'=>[sbl_id,'2<ptr,ptr>'],

  'pop'=>[sbl_id,'*1<ptr>'],
  'push'=>[sbl_id,'1<ptr|bare>'],

  'inc'=>[sbl_id,'1<ptr>'],
  'dec'=>[sbl_id,'1<ptr>'],
  'clr'=>[sbl_id,'1<ptr>'],

  'exit'=>[sbl_id,'1<ptr|bare>'],

};

# ---   *   ---   *   ---

use constant DIRECTIVE=>{

  'reg'=>[sbl_id,'1<bare>'],
  'rom'=>[sbl_id,'1<bare>'],

  'clan'=>[sbl_id,'1<bare>'],
  'proc'=>[sbl_id,'1<bare>'],

  'entry'=>[sbl_id,'1<ptr>'],
  'atexit'=>[sbl_id,'1<ptr>'],

};

# ---   *   ---   *   ---

use constant FCTL=>{

  'jmp'=>[sbl_id,'1<ptr>'],
  'jif'=>[sbl_id,'2<ptr,ptr|bare>'],
  'eif'=>[sbl_id,'2<ptr,ptr|bare>'],

  #:*;> not yet implemented
  'call'=>[sbl_id,'1<ptr>'],
  'ret'=>[sbl_id,'1<ptr>'],
  'wait'=>[sbl_id,'1<ptr>'],

};

# ---   *   ---   *   ---
# missing/needs rethinking:
# str,buf,fptr,lis,lock

use constant INTRINSIC=>{

  'wed'=>[sbl_id,'1<bare>'],
  'unwed'=>[sbl_id,'0'],

};

use constant SPECIFIER=>{

  'ptr'=>[sbl_id,'0'],
  'fptr'=>[sbl_id,'0'],

  'str'=>[sbl_id,'0'],
  'buf'=>[sbl_id,'0'],
  'tab'=>[sbl_id,'0'],

};

# ---   *   ---   *   ---
# UTILS

# ---   *   ---   *   ---
# sets up nodes such that:
#
# >clan
# \-->reg
# .  \-->proc
# .
# .
# \-->reg
# .
# >clan

sub reorder($) {

  my $tree=shift;
  my $root=$tree;

  my $anchor=$root;
  my @anchors=($root,undef,undef,undef);

  my $scopers=qr/\b(clan|reg|rom|proc)\b/;

# ---   *   ---   *   ---
# iter tree

  for my $leaf(@{$tree->leaves}) {
    if($leaf->value=~ $scopers) {
      my $match=$1;

# ---   *   ---   *   ---

      if(@anchors) {
        if($match eq 'clan') {
          $anchors[1]=$leaf;
          $anchor=$root;

# ---   *   ---   *   ---

        } elsif($match eq 'reg') {
          $anchor=$anchors[1];
          @anchors[2]=$leaf;

# ---   *   ---   *   ---

        } elsif($match eq 'proc') {
          $anchor=$anchors[2];
          @anchors[3]=$leaf;

        };

# ---   *   ---   *   ---
# move node and reset anchor

      };if($leaf->par ne $anchor) {
        ($leaf)=$leaf->par->pluck($leaf);
        $anchor->pushlv(0,$leaf);

      };$anchor=$leaf;

# ---   *   ---   *   ---
# node doesn't modify anchor

    } elsif($leaf->par ne $anchor) {
      ($leaf)=$leaf->par->pluck($leaf);
      $anchor->pushlv(0,$leaf);

    };
  };
};

# ---   *   ---   *   ---

BEGIN {
  sbl_new(1);

# ---   *   ---   *   ---

DEFINE 'cpy',BUILTIN,sub {

  my ($inskey,$frame,$field)=@_;
  my ($dst,$src)=@$field;

  my $fr_ptr=$frame->master->ptr;

  if($fr_ptr->valid($src)) {
    $src=$src->addr;

  };if(!$fr_ptr->valid($dst)) {
    $dst=$fr_ptr->fetch($dst);

  };$dst->setv($src);

};

# ---   *   ---   *   ---

DEFINE 'pop',BUILTIN,sub {

  my ($inskey,$frame,$dst)=@_;
  my $fr_ptr=$frame->master->ptr;
  my $fr_blk=$frame->master->blk;

  $dst=$dst->[0];

  my $v=$fr_blk->spop();

  if($fr_ptr->valid($dst)) {
    $dst=$fr_ptr->fetch($dst);
    $dst->setv($v);

  };

};

# ---   *   ---   *   ---

DEFINE 'push',BUILTIN,sub {

  my ($inskey,$frame,$src)=@_;
  my $fr_ptr=$frame->master->ptr;
  my $fr_blk=$frame->master->blk;

  $src=$src->[0];

  if($fr_ptr->valid($src)) {
    $src=$src->addr;

  };

  $fr_blk->spush($src);

};

# ---   *   ---   *   ---

DEFINE 'inc',BUILTIN,sub {

  my ($inskey,$frame,$ptr)=@_;
  my $fr_ptr=$frame->master->ptr;

  $ptr=$ptr->[0];

  $ptr=$fr_ptr->fetch($ptr);
  $ptr->setv($ptr->getv()+1);

};

# ---   *   ---   *   ---

DEFINE 'dec',BUILTIN,sub {

  my ($inskey,$frame,$ptr)=@_;
  my $fr_ptr=$frame->master->ptr;

  $ptr=$ptr->[0];

  $ptr=$fr_ptr->fetch($ptr);
  $ptr->setv($ptr->getv()-1);

};

# ---   *   ---   *   ---

DEFINE 'clr',BUILTIN,sub {

  my ($inskey,$frame,$ptr)=@_;
  my $fr_ptr=$frame->master->ptr;

  $ptr=$ptr->[0];

  $ptr=$fr_ptr->fetch($ptr);
  $ptr->setv(0);

};

# ---   *   ---   *   ---

DEFINE 'exit',BUILTIN,sub {

  my ($inskey,$frame,$val)=@_;
  my $master=$frame->master;

  $val=$val->[0];

  # placeholder!
  printf sprintf "Exit code <0x%.2X>\n",$val;
  $master->setnxins(-2);

};

# ---   *   ---   *   ---

DEFINE 'reg',DIRECTIVE,sub {

  my ($inskey,$frame,$name)=@_;

  my $fr_ptr=$frame->master->ptr;
  my $fr_blk=$frame->master->blk;

  $name=$name->[0];

  # get dst
  my $dst=($fr_blk->DST->attrs)
    ? $fr_blk->DST->par
    : $fr_blk->DST
    ;

# ---   *   ---   *   ---

  my $blk;

  # append new block to dst on first pass
  if($fr_blk->fpass()) {
    $blk=$fr_blk->nit(
      $dst,$name,O_RDWR,

    );

  # second pass: look for block
  } else {
    $blk=$fr_ptr->fetch($name)->blk;

  };

# ---   *   ---   *   ---
# overwrite dst

  $fr_blk->DST($blk);
  $fr_blk->setscope($blk);
  $fr_blk->setcurr($blk);

};

# ---   *   ---   *   ---

DEFINE 'clan',DIRECTIVE,sub {

  my ($inskey,$frame,$name)=@_;

  my $fr_ptr=$frame->master->ptr;
  my $fr_blk=$frame->master->blk;

  $name=$name->[0];

  my $dst=$fr_blk->NON;

# ---   *   ---   *   ---

  # is not global scope/root
  my $blk;if($name ne 'non') {

    # first pass: create new block
    if($fr_blk->fpass()) {
      $blk=$fr_blk->nit(undef,$name);

    # second pass: find block
    } else {
      $blk=$fr_ptr->fetch($name)->blk;

    };

# ---   *   ---   *   ---

  # is global scope
  } else {$blk=$dst;};

  $fr_blk->DST($blk);
  $fr_blk->setcurr($blk);

  return $blk;

};

# ---   *   ---   *   ---

DEFINE 'proc',DIRECTIVE,sub {

  my ($inskey,$frame,$name)=@_;

  my $fr_ptr=$frame->master->ptr;
  my $fr_blk=$frame->master->blk;

  $name=$name->[0];

  # get dst
  my $dst=($fr_blk->DST->attrs)
    ? $fr_blk->DST->par
    : $fr_blk->DST
    ;

# ---   *   ---   *   ---

  my $blk;

  # append new block to dst on first pass
  if($fr_blk->fpass()) {
    $blk=$dst->nit(
      $dst,$name,O_EX,

    );

  # second pass: look for block
  } else {
    $fr_ptr->fetch($name)->blk;

  };

# ---   *   ---   *   ---
# overwrite dst

  $fr_blk->DST($blk);
  $fr_blk->setcurr($blk);
  $fr_blk->setscope($blk->scope);

};

# ---   *   ---   *   ---

DEFINE 'entry',DIRECTIVE,sub {

  my ($inskey,$frame,$blk)=@_;
  my $fr_blk=$frame->master->blk;

  $blk=$blk->[0];
  $fr_blk->entry($blk);

};

# ---   *   ---   *   ---

DEFINE 'jmp',FCTL,sub {

  my ($inskey,$frame,$ptr)=@_;

  my $master=$frame->master;
  my $fr_ptr=$master->ptr;

  $ptr=$ptr->[0];

  # set instruction index to ptr loc
  $master->setnxins(
    $fr_ptr->fetch($ptr)->blk->insid

  );
};

# ---   *   ---   *   ---

DEFINE 'wed',INTRINSIC,sub {

  my ($inskey,$frame,$type)=@_;
  my $fr_ptr=$frame->master->ptr;

  $type=$type->[0];
  $fr_ptr->wed($type);

};

# ---   *   ---   *   ---

DEFINE 'unwed',INTRINSIC,sub {

  my ($inskey,$frame)=@_;
  my $fr_ptr=$frame->master->ptr;

  $fr_ptr->wed(undef);

};

# ---   *   ---   *   ---

DEFINE 'value_decl',TYPE,sub {

  my ($inskey,$frame,$names,$values)=@_;

  my $fr_blk=$frame->master->blk;
  my $fr_ptr=$frame->master->ptr;
  my $lang=$frame->master->lang;

  my $dst=$fr_blk->DST;
  my $skey=undef;

  my $intrinsic=$lang->intrinsics;

# ---   *   ---   *   ---

  if($inskey=~ s/${intrinsic}//) {
    my $ins=$1;

    if($ins eq 'ptr') {
      $skey='unit';

    };
  };

  $inskey=~ s/\s+$//;

  my $wed=$fr_ptr->wed('get');
  $fr_ptr->wed($inskey);

# ---   *   ---   *   ---
# fill out values with zeroes if need

  my @line=();

  if(!defined $values) {

    $values=[];

    for(my $i=0;$i<@$names;$i++) {
      push @$values,0;

    };

  };

# ---   *   ---   *   ---
# make [name,value] ref array

  my $i=0;if(@$names >= @$values) {

    for my $name(@$names) {

      my $value=(defined $values->[$i])
        ? $values->[$i]
        : 0
        ;

      $line[$i]=[$name,$value];$i++;

    };

# ---   *   ---   *   ---

  } else {

    my $j=1;
    for my $value(@$values) {

      my $name=$names->[$i];
      if($fr_blk->fpass()) {
        $name=(defined $name)
          ? $name
          : "$names->[-1]+".($j++)
          ;

# ---   *   ---   *   ---

      } else {

        $name=(defined $name)
          ? $name
          : $names->[-1]+($j++)
          ;

      };$line[$i]=[$name,$value];$i++;

    };
  };

# ---   *   ---   *   ---
# alternate storage type

  my $ptrtype=$inskey;
  if(defined $skey) {
    $inskey=$skey;

  };$fr_ptr->wed($inskey);

# ---   *   ---   *   ---
# grow block on first pass

  if($fr_blk->fpass()) {

    # grow the block
    $dst->expand(\@line,$inskey);

# ---   *   ---   *   ---
# initialize/overwrite values on second pass

  } else {

    for my $pair(@line) {

      my $ptr=$pair->[0];
      my $value=$pair->[1];

      $ptr=$fr_ptr->fetch($ptr);
      $ptr->mask_to($ptrtype);

      if(!$value && $inskey eq 'unit') {
        $value=$fr_ptr->NULL;

      };

      $ptr->setv($value);

    };

  };$fr_ptr->wed($wed);
};

# ---   *   ---   *   ---
# DEFS END

# ---   *   ---   *   ---
# alternate names for certain calls

ALIAS 'char','value_decl';

# ---   *   ---   *   ---

lang::def::nit(

  -NAME=>'peso',

  -EXT=>'\.(pe)$',
  -HED=>'\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$',
  -MAG=>'$ program',

  -OP_PREC=>peso::ops->def,
  -SBL=>$SBL_TABLE,

# ---   *   ---   *   ---

  -TYPES=>[
    keys %{&TYPE},

  ],

  -SPECIFIERS=>[
    keys %{&SPECIFIER},

  ],

  -RESNAMES=>[qw(
    self other null non

  )],

# ---   *   ---   *   ---

  -INTRINSICS=>[
    keys %{&INTRINSIC},

  ],

  -DIRECTIVES=>[
    keys %{&DIRECTIVE},

  ],

# ---   *   ---   *   ---

  -BUILTINS=>[qw(

    mem fre shift unshift
    kin sow reap sys stop

  ),keys %{&BUILTIN},

  ],

# ---   *   ---   *   ---

  -MCUT_TAGS=>[-STRING,-CHAR],

# ---   *   ---   *   ---

);lang->peso->{-PLPS}
    =langdefs::plps::make(lang->peso);

};

# ---   *   ---   *   ---
1; # ret
