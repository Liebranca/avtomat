#!/usr/bin/perl
# ---   *   ---   *   ---
# DEFS
# Where names be given meaning
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::defs;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

  use peso::decls;


# ---   *   ---   *   ---
# shorthand to $fr_sbl->DEFINE/ALIAS

sub DEFINE($$$) {

  lang->peso->sbl->DEFINE(
    $_[0],$_[1],$_[2],

  );
};

# ---   *   ---   *   ---

sub ALIAS($$) {

  lang->peso->sbl->DEFINE(
    $_[0],$_[1],$_[2],

  );
};

# ---   *   ---   *   ---
# defs for declared symbols

# ---   *   ---   *   ---

DEFINE 'cpy',peso::decls->BAFA,sub {

  my ($frame,$inskey,$field)=@_;
  my ($dst,$src)=@$field;

  my $fr_ptr=$frame->master->ptr;

  if($fr_ptr->valid($src)) {
    $src=$src->addr;

  };if(!$fr_ptr->valid($dst)) {
    $dst=$fr_ptr->fetch($dst);

  };$dst->setv($src);

};

# ---   *   ---   *   ---

DEFINE 'pop',peso::decls->BAFA,sub {

  my ($frame,$inskey,$dst)=@_;
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

DEFINE 'push',peso::decls->BAFA,sub {

  my ($frame,$inskey,$src)=@_;
  my $fr_ptr=$frame->master->ptr;
  my $fr_blk=$frame->master->blk;

  $src=$src->[0];

  if($fr_ptr->valid($src)) {
    $src=$src->addr;

  };

  $fr_blk->spush($src);

};

# ---   *   ---   *   ---

DEFINE 'inc',peso::decls->BAFA,sub {

  my ($frame,$inskey,$ptr)=@_;
  my $fr_ptr=$frame->master->ptr;

  $ptr=$ptr->[0];

  $ptr=$fr_ptr->fetch($ptr);
  $ptr->setv($ptr->getv()+1);

};

# ---   *   ---   *   ---

DEFINE 'dec',peso::decls->BAFA,sub {

  my ($frame,$inskey,$ptr)=@_;
  my $fr_ptr=$frame->master->ptr;

  $ptr=$ptr->[0];

  $ptr=$fr_ptr->fetch($ptr);
  $ptr->setv($ptr->getv()-1);

};

# ---   *   ---   *   ---

DEFINE 'clr',peso::decls->BAFA,sub {

  my ($frame,$inskey,$ptr)=@_;
  my $fr_ptr=$frame->master->ptr;

  $ptr=$ptr->[0];

  $ptr=$fr_ptr->fetch($ptr);
  $ptr->setv(0);

};

# ---   *   ---   *   ---

DEFINE 'exit',peso::decls->BAFA,sub {

  my ($frame,$inskey,$val)=@_;
  my $master=$frame->master;

  $val=$val->[0];

  # placeholder!
  printf sprintf "Exit code <0x%.2X>\n",$val;
  $master->setnxins(-2);

};

# ---   *   ---   *   ---

DEFINE 'reg',peso::decls->BAFB,sub {

  my ($frame,$inskey,$name)=@_;

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
      $name,$fr_blk->O_RDWR,

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

DEFINE 'clan',peso::decls->BAFB,sub {

  my ($frame,$inskey,$name)=@_;

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

};

# ---   *   ---   *   ---

DEFINE 'proc',peso::decls->BAFB,sub {

  my ($frame,$inskey,$name)=@_;

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
      $name,$fr_blk->O_EX,

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

DEFINE 'entry',peso::decls->BAFB,sub {

  my ($frame,$inskey,$blk)=@_;
  my $fr_blk=$frame->master->blk;

  $blk=$blk->[0];
  $fr_blk->entry($blk);

};

# ---   *   ---   *   ---

DEFINE 'jmp',peso::decls->BAFC,sub {

  my ($frame,$inskey,$ptr)=@_;

  my $master=$frame->master;
  my $fr_ptr=$master->ptr;

  $ptr=$ptr->[0];

  # set instruction index to ptr loc
  $master->setnxins(
    $fr_ptr->fetch($ptr)->blk->insid

  );
};

# ---   *   ---   *   ---

DEFINE 'wed',peso::decls->BAFD,sub {

  my ($frame,$inskey,$type)=@_;
  my $fr_ptr=$frame->master->ptr;

  $type=$type->[0];
  $fr_ptr->wed($type);

};

# ---   *   ---   *   ---

DEFINE 'unwed',peso::decls->BAFD,sub {

  my ($frame,$inskey)=@_;
  my $fr_ptr=$frame->master->ptr;

  $fr_ptr->wed(undef);

};

# ---   *   ---   *   ---

DEFINE 'value_decl',peso::decls->BAFE,sub {

  my ($frame,$inskey,$names,$values)=@_;

  my $fr_blk=$frame->master->blk;
  my $fr_ptr=$frame->master->ptr;
  my $lang=$frame->master->lang;

  my $dst=$fr_blk->DST;
  my $skey=undef;

  my $intrinsic=$lang->vars->[0];

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
# defs end

# ---   *   ---   *   ---
# alternate names for certain calls

ALIAS 'char','value_decl';

# ---   *   ---   *   ---
1; # ret

