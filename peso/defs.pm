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

  use peso::decls;
  use peso::symbol;
  use peso::ptr;
  use peso::block;

# ---   *   ---   *   ---
# global state

  my %CACHE=(

    -SYMS=>{},
    -INS=>[],

    -INSID=>{},

  );

# ---   *   ---   *   ---
# getters

sub SYMS {return $CACHE{-SYMS};};
sub INS {return $CACHE{-INS};};
sub INSID {return $CACHE{-INSID};};

# ---   *   ---   *   ---
# constructor, or rather shorthand

sub DEFINE {

  my $key=shift;
  my $src=shift;

  my $code=shift;
  my $idex=$src->{$key}->[0];
  my $args=$src->{$key}->[1];

  my $sym=peso::symbol::nit($key,$args,$code);

  INS->[$idex]=SYMS->{$key}=$sym;
  INSID->{$key}=$idex;

};sub ALIAS {

  my $key=shift;
  my $src=shift;

  my $sym=peso::symbol::dup(
    SYMS->{$src},$key

  );

  my $idex=INSID->{$src};

  INS->[$idex]=SYMS->{$key}=$sym;
  INSID->{$key}=$idex;

};

# ---   *   ---   *   ---
# defs for declared symbols

# ---   *   ---   *   ---

DEFINE('cpy',peso::decls::bafa,sub {

  my $inskey=shift;
  my $field=shift;

  my ($dst,$src)=@$field;

  if(peso::ptr::valid($src)) {
    $src=$src->addr;

  };if(!peso::ptr::valid($dst)) {
    $dst=peso::ptr::fetch($dst);

  };$dst->setv($src);

});

# ---   *   ---   *   ---

DEFINE('pop',peso::decls::bafa,sub {

  my $inskey=shift;
  my $dst=(shift)->[0];

  my $v=peso::block::spop();

  if(peso::ptr::valid($dst)) {
    $dst=peso::ptr::fetch($dst);
    $dst->setv($v);

  };

});

# ---   *   ---   *   ---

DEFINE('push',peso::decls::bafa,sub {

  my $inskey=shift;
  my $src=(shift)->[0];

  if(peso::ptr::valid($src)) {
    $src=$src->addr;

  };

  peso::block::spush($src);

});

# ---   *   ---   *   ---

DEFINE('inc',peso::decls::bafa,sub {

  my $inskey=shift,
  my $ptr=(shift)->[0];

  $ptr=peso::ptr::fetch($ptr);
  $ptr->setv($ptr->getv()+1);

});

# ---   *   ---   *   ---

DEFINE('dec',peso::decls::bafa,sub {

  my $inskey=shift,
  my $ptr=(shift)->[0];

  $ptr=peso::ptr::fetch($ptr);
  $ptr->setv($ptr->getv()-1);

});

# ---   *   ---   *   ---

DEFINE('clr',peso::decls::bafa,sub {

  my $inskey=shift,
  my $ptr=(shift)->[0];

  $ptr=peso::ptr::fetch($ptr);
  $ptr->setv(0);

});

# ---   *   ---   *   ---

DEFINE('exit',peso::decls::bafa,sub {

  my $inskey=shift;
  my $val=(shift)->[0];

  # placeholder!
  printf sprintf "Exit code <0x%.2X>\n",$val;
  peso::program::setnxins(-2);

});

# ---   *   ---   *   ---

DEFINE('reg',peso::decls::bafb,sub {

  my $inskey=shift;
  my $name=(shift)->[0];

  # get dst
  my $dst=(peso::block::DST->attrs)
    ? peso::block::DST->par
    : peso::block::DST
    ;

# ---   *   ---   *   ---

  my $blk;

  # append new block to dst on first pass
  if(peso::block::fpass()) {
    $blk=$dst->nit(
      $name,peso::block->O_RDWR,

    );

  # second pass: look for block
  } else {
    $blk=peso::ptr::fetch($name)->blk;

  };

# ---   *   ---   *   ---
# overwrite dst

  peso::block::DST($blk);
  peso::block::setscope($blk);
  peso::block::setcurr($blk);

});

# ---   *   ---   *   ---

DEFINE('clan',peso::decls::bafb,sub {

  my $inskey=shift;
  my $name=(shift)->[0];

  my $dst=peso::block::NON;

# ---   *   ---   *   ---

  # is not global scope/root
  my $blk;if($name ne 'non') {

    # first pass: create new block
    if(peso::block::fpass()) {
      $blk=peso::block::nit(undef,$name);

    # second pass: find block
    } else {
      $blk=peso::ptr::fetch($name)->blk;

    };

# ---   *   ---   *   ---

  # is global scope
  } else {$blk=$dst;};
  peso::block::DST($blk);
  peso::block::setcurr($blk);

});

# ---   *   ---   *   ---

DEFINE('proc',peso::decls::bafb,sub {

  my $inskey=shift;
  my $name=(shift)->[0];

  # get dst
  my $dst=(peso::block::DST->attrs)
    ? peso::block::DST->par
    : peso::block::DST
    ;

# ---   *   ---   *   ---

  my $blk;

  # append new block to dst on first pass
  if(peso::block::fpass()) {
    $blk=$dst->nit(
      $name,peso::block->O_EX,

    );

  # second pass: look for block
  } else {
    $blk=peso::ptr::fetch($name)->blk;

  };

# ---   *   ---   *   ---
# overwrite dst

  peso::block::DST($blk);
  peso::block::setcurr($blk);
  peso::block::setscope($blk->scope);

});

# ---   *   ---   *   ---

DEFINE('entry',peso::decls::bafb,sub {

  my $inskey=shift;
  my $name=(shift)->[0];

  peso::block::entry($name);

});

# ---   *   ---   *   ---

DEFINE('jmp',peso::decls::bafc,sub {

  my $inskey=shift;
  my $ptr=(shift)->[0];

  # set instruction index to ptr loc
  peso::program::setnxins(
    peso::ptr::fetch($ptr)->blk->insid

  );

});

# ---   *   ---   *   ---

DEFINE('wed',peso::decls::bafd,sub {

  my $inskey=shift;
  my $type=(shift)->[0];

  peso::ptr::wed($type);

});

# ---   *   ---   *   ---

DEFINE('unwed',peso::decls::bafd,sub {

  my $inskey=shift;
  peso::ptr::wed(undef);

});

# ---   *   ---   *   ---

DEFINE('cmp',peso::decls::bafd,sub {

  my $node=shift;

  my $v0=$node->group(0,0)->val;
  my $v1=$node->group(0,1)->val;

  return int($v0 eq $v1);

});

# ---   *   ---   *   ---

DEFINE('value_decl',peso::decls::bafe,sub {

  my $inskey=shift;

  my $names=shift;
  my $values=shift;

  my $dst=peso::block::DST;

  my $skey=undef;

  my $intrinsic=peso::decls::intrinsic;

# ---   *   ---   *   ---

  if($inskey=~ s/${intrinsic}//) {
    my $ins=$1;

    if($ins eq 'ptr') {
      $skey='unit';

    };
  };

  $inskey=~ s/\s+$//;

  my $wed=peso::ptr::wed('get');
  peso::ptr::wed($inskey);

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

  } else {

    my $j=1;
    for my $value(@$values) {

      my $name=$names->[$i];
      if(peso::block::fpass()) {
        $name=(defined $name)
          ? $name
          : "$names->[-1]+".($j++)
          ;

      } else {

        $name=(defined $name)
          ? $name
          : $names->[-1]+($j++)
          ;

      };

      $line[$i]=[$name,$value];$i++;

    };

  };

# ---   *   ---   *   ---
# alternate storage type

  my $ptrtype=$inskey;
  if(defined $skey) {
    $inskey=$skey;

  };peso::ptr::wed($inskey);

# ---   *   ---   *   ---
# grow block on first pass

  if(peso::block::fpass()) {

    # grow the block
    $dst->expand(\@line,$inskey);

# ---   *   ---   *   ---
# initialize/overwrite values on second pass

  } else {

    for my $pair(@line) {

      my $ptr=$pair->[0];
      my $value=$pair->[1];

      $ptr=peso::ptr::fetch($ptr);
      $ptr->mask_to($ptrtype);

      if(!$value && $inskey eq 'unit') {
        $value=peso::ptr->NULL;

      };

      $ptr->setv($value);

    };

  };peso::ptr::wed($wed);
});

# ---   *   ---   *   ---

ALIAS('char','value_decl');

# ---   *   ---   *   ---
# defs end

# ---   *   ---   *   ---
# misc definitions

my $NUMCON=[

  # hex conversion
  [ lang::DICT->{-GPRE}->{-NUMS}->[0]->[1],
    \&lang::pehexnc

  ],

  # ^bin
  [ lang::DICT->{-GPRE}->{-NUMS}->[1]->[1],
    \&lang::pebinnc

  ],

  # ^octal
  [ lang::DICT->{-GPRE}->{-NUMS}->[2]->[1],
    \&lang::peoctnc

  ],

  # decimal notation: as-is
  [ '(((\b[1-9][0-9]*|\.)+[0-9]+f?)\b)|'.
    '(\b[1-9][0-9]*\b)',

    sub {return (shift);}

  ],

];sub NUMCON {return $NUMCON;};

# ---   *   ---   *   ---
1; # ret
