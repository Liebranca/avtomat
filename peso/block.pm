#!/usr/bin/perl
# ---   *   ---   *   ---
# BLOCK
# Makes perl reps of peso objects
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::block;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/include/';
  use lib $ENV{'ARPATH'}.'/lib/';

  use peso::decls;
  use peso::ptr;

  use stack;

# ---   *   ---   *   ---

  use constant {

    # permissions
    O_RD=>0b001,
    O_WR=>0b010,
    O_EX=>0b100,

    # just for convenience
    O_RDWR=>0b011,
    O_RDEX=>0b101,
    O_WREX=>0b110,

    O_RDWREX=>0b111,

    # pretty hexspeak
    FREEBLOCK=>0xF9EEB10C,

  };

# ---   *   ---   *   ---

my %CACHE=(

  -SELF=>undef,
  -SOIL=>undef,
  -CURR=>undef,

  -DST=>undef,

  -BLOCKS=>undef,
  -BBID=>[0..0xFF],
  -BIDS=>stack::nit(stack::slidex(0x100)),

  -DATA=>[],

  -INS=>[],
  -INS_KEY=>{},
  -INS_ARR=>[],

  -NXINS=>0,
  -ENTRY=>'nit',

  -NODES=>[],
  -PASS=>0,
  -DPTR=>[],

  -PRSTK=>undef,

);

# ---   *   ---   *   ---
# in: block name
# errchk and get root block

sub clan {

  my $key=shift;

# ---   *   ---   *   ---
# return local scope

  if($key eq 'self') {
    return $CACHE{-SELF};

# ---   *   ---   *   ---
# return base block

  } elsif($key eq 'non') {
    return $CACHE{-SOIL};

# ---   *   ---   *   ---
# name lookup

  } elsif(peso::ptr::is_block_ref($key)) {
    return peso::ptr::fetch($key)->blk;

# ---   *   ---   *   ---
# throw err

  } else {
    printf "No root block named '$key'\n";
    exit;

  };

};

# ---   *   ---   *   ---
# in: block instance
# scope to block

sub setscope {

  my $self=shift;
  $CACHE{-SELF}=$self;

  if(!$self->{-SCOPE}) {
    $self->{-SCOPE}=$self;

  };

# ---   *   ---   *   ---
# add scope names to list

  my @ar=($CACHE{-SELF}->ances);
  if(defined $CACHE{-CURR}) {

    my $curr=$CACHE{-CURR};
    push @ar,$curr->ances;

    if(defined $curr->par) {
      push @ar,$curr->par->ances;

    };

  };

# ---   *   ---   *   ---
# ensure global scope is... well, global

  my $hasnon=0;
  for my $name(@ar) {
    if($name eq 'non') {
      $hasnon=1;
      last;

    };
  };

  if(!$hasnon) {push @ar,'non';};
  peso::ptr::setscope(@ar);

};

# ---   *   ---   *   ---
# in: block instance
# set current local space

sub setcurr {$CACHE{-CURR}=shift;};

# ---   *   ---   *   ---
# program stack methods

sub prstk {return $CACHE{-PRSTK};};

sub spush {

  my $v=shift;
  prstk()->spush($v);

};sub spop {

  my $v=prstk()->spop();
  return $v;

};

# ---   *   ---   *   ---
# we have to load the instruction set
# from an external hash for complex reasons
# i can make it all internal later (maybe)

sub loadins {

  my $ref=shift;my $i=0;
  for my $key(keys %$ref) {
    push @{$CACHE{-INS}},$ref->{$key};
    $CACHE{-INS_KEY}->{$key}=$i;$i++;

  };

# ---   *   ---   *   ---
# get idex of instruction

};sub getinsi {

  my $name=shift;$name=~ s/\s*$//;
  return $CACHE{-INS_KEY}->{$name};

# save node/tree for later use
};sub setnode {

  my $node=shift;

  push @{$CACHE{-NODES}},$node;
  return int(@{$CACHE{-NODES}})-1;

# ^get saved node from index
};sub getnode {

  my $idex=shift;
  return $CACHE{-NODES}->[$idex];

};

# ---   *   ---   *   ---
# execute program as defined by blocks

sub ex {

  my $entry=$CACHE{-ENTRY};
  my $non=$CACHE{-SOIL};

  peso::ptr::wed(undef);

  # get entry point block
  $entry=peso::ptr::fetch($entry)->blk;
  setnxins($entry->insid);

  # scope to block
  setcurr($entry);
  setscope($entry->{-SCOPE});

  # debug: print out what we're executing
  printf "ex ".$entry->name."\n";

  # execute until end
  while(!(nxins()<0)) {
    $entry=$entry->exnext();

    if(nxins()<0) {last;};

  };

};

# ---   *   ---   *   ---
# get next instruction

sub exfetnx {

  my $self=shift;
  my $i=nxins();

  if($i<0) {return (undef,undef,undef);};

  my $nx=sprintf "_%.08i",$i;

  my $ins='ins'.$nx;
  my $arg='arg'.$nx;

# ---   *   ---   *   ---
# when instruction not found in current,
# find block matching instruction index

  if(!exists $self->elems->{$ins}) {
    $self=getinsid($i);

  };

  return ($self,$ins,$arg);

# ---   *   ---   *   ---
# get instruction matching index

};sub getinsid {

  my $i=shift;
  my $blk=$CACHE{-INS_ARR}->[$i];

  # scope to block
  setcurr($blk);
  setscope($blk->{-SCOPE});

  # debug: print out what we're executing
  printf "ex ".$blk->name."\n";

# ---   *   ---   *   ---
# catch: no instruction matches index

  if(!defined $blk) {

    printf "EX_END: instruction fetch fail!\n";
    exit;

  };return $blk;

};

# ---   *   ---   *   ---
# execute next instruction in stack

sub exnext {

  my $self=shift;
  my ($ins,$arg)=(0,0);

  # get idex of instruction
  my $i=nxins();

  # fetch instruction matching idex
  ($self,$ins,$arg)=$self->exfetnx();
  if(!defined $self) {return;};

# ---   *   ---   *   ---
# decode instruction/argument ptrs

  $ins=$self->getv($ins);
  $arg=$self->getv($arg);

  # duplicate node containing args
  $arg=getnode($arg);
  my $ori=$arg;
  $arg=$arg->dup();

  # execute instruction
  $CACHE{-INS}->[$ins]->ex($arg);

  # increase stack ptr if !jmp
  if($i == nxins()) {incnxins();};
  return $self;

};

# ---   *   ---   *   ---
# in: name, write/read/exec permissions
# creates a new data/instruction block

sub nit {

  my $self=shift;
  my $name=shift;
  my $attrs=shift;

  # default to all protected
  if(!defined $attrs) {
    $attrs=0b000;

  };

  my $insid=($attrs& O_EX)
    ? $CACHE{-NXINS}
    : -1
    ;

  my $blk=bless {

    -NAME=>$name,
    -SIZE=>0,

    -PAR=>$self,
    -CHILDREN=>[],
    -STACK=>stack::nit(stack::slidex(0x100)),
    -SCOPE=>$CACHE{-SELF},

    -ELEMS=>{},
    -ATTRS=>$attrs,
    -INSID=>$insid,

    -ID=>undef,

  },'peso::block';

  # initialized from instance
  # new->setParent $self
  if(defined $self) {
    $self->elems->{$name}=$blk;

  # is root block
  } else {

    if(exists $CACHE{-BLOCKS}->{$name}) {

      printf "Ilegal operation: ".
        "redeclaration of root block '".
        $name."' at global scope\n";

      exit;

    };$self=$CACHE{-SOIL};

    $blk->{-ID}=$CACHE{-BIDS}->spop();
    $CACHE{-BBID}->[$blk->{-ID}]=$blk;

# ---   *   ---   *   ---

  };if($name ne 'non') {
    $self->addchld($blk);

  };

  if($insid>=0) {
    $CACHE{-INS_ARR}->[$insid]=$blk;

  };

  return $blk;

};

# ---   *   ---   *   ---
# initialize globals

sub gblnit {

  my $tab=shift;

  $CACHE{-SOIL}=nit(undef,'non');
  $CACHE{-BLOCKS}=$CACHE{-SOIL}->{-ELEMS};
  $CACHE{-PRSTK}=stack::nit(0,[]);

  loadins($tab);
  setnxins(0);

  return $CACHE{-SOIL};

};

# ---   *   ---   *   ---
# convenience settings for sub-blocks

sub addchld {

  my $self=shift;
  my $blk=shift;

  my $i=$self->sstack->spop();
  my $j=$self->{-ID};

  # add block data into this line
  my @line=(

    [$blk->name,$blk],

  );

# ---   *   ---   *   ---

  my $bypass=int(
    $self->name eq 'non'
  ||!$self->attrs

  );

  $self->expand(\@line,'long',$bypass);
  $self->children->[$i]=$blk;
  $blk->{-PAR}=$self;

  peso::ptr::declscope(
    $blk->ances,@{peso::ptr::MEM()}

  );

};

# ---   *   ---   *   ---
# getters

sub name {return (shift)->{-NAME};};
sub elems {return (shift)->{-ELEMS};};
sub par {return (shift)->{-PAR};};
sub children {return (shift)->{-CHILDREN};};
sub sstack {return (shift)->{-STACK};};
sub data {return $CACHE{-DATA};};
sub size {return (shift)->{-SIZE};};
sub attrs {return (shift)->{-ATTRS};};
sub nxins {return $CACHE{-NXINS};};
sub insid {return (shift)->{-INSID};};
sub fpass {return !$CACHE{-PASS};};

# ---   *   ---   *   ---
# adjusts current write-to

sub DST {

  my $new=shift;
  if(defined $new) {
    $CACHE{-DST}=$new;

  };return $CACHE{-DST};

};

# ---   *   ---   *   ---
# find ancestors recursively

sub ances {

  my $self=shift;
  my $name=$self->name;

  if($self->par) {
    $name=$self->par->ances().'@'.$name;

  };return $name;

};

# ---   *   ---   *   ---
# setters

sub entry {$CACHE{-ENTRY}=shift;};
sub incpass {$CACHE{-PASS}++;};

sub setnxins {$CACHE{-NXINS}=shift};
sub incnxins {$CACHE{-NXINS}++};

# ---   *   ---   *   ---
# in: block, element name
# lookup errme shorthand

sub no_such_elem {

  my $self=shift;
  my $name=shift;

  printf "Block <".$self->ances.'> '.
  "has no member named '".$name."'\n";

  exit;

};

# ---   *   ---   *   ---

# in: element name, redecl guard
# errcheck for bad fetch

sub haselem {

  my $self=shift;
  my $name=shift;
  my $redecl=shift;

# ---   *   ---   *   ---
# solve compound name (module@sub@elem)

  if($name=~ m/@/) {
    my $blk=peso::ptr::fetch($name)->blk;
    $self=$blk;

# ---   *   ---   *   ---
# element not found (plain name)

  } elsif(

     !exists $self->elems->{$name}
  && !defined $redecl

  ) {$self->no_such_elem($name);}

# ---   *   ---   *   ---
# redeclaration guard

  elsif(

     exists $self->elems->{$name}
  && defined $redecl

  ) {

    # block-as-elem is exempt from redecl
    if(0>=index $self->elems->{$name},
      "peso::block"

    ) {return;};

    printf "Redeclaration of '$name' ".
      'at block <'.$self->ances.">\n";

    exit;

  # return match
  };return ($self,$name);

};

# ---   *   ---   *   ---
# in: array of [key,value] references,
# in: data type

# inserts new elements into block

sub expand {

  my $self=shift;
  my $ref=shift;
  my $type=shift;
  my $bypass=shift;

# ---   *   ---   *   ---
# get size from type, in bytes

  my $elem_sz=peso::decls::sizes->{$type};
  my $inc_size=@$ref*$elem_sz;

# ---   *   ---   *   ---
# 'line' is two units
# 'unit' is 64-bit chunk
# we use these as minimum size for blocks

  my $line_sz=peso::decls::sizes->{'line'};
  my $gran=(1<<($elem_sz*8))-1;

# ---   *   ---   *   ---
# grow block on first pass

  my $j=0;if(fpass()) {

    # save top of stack
    $j=@{peso::ptr::MEM()};
    $self->{-SIZE}+=$inc_size;

    # reserve new unit
    peso::ptr::nunit();

  };

# ---   *   ---   *   ---
# push elements to data

  my $i=0;while(@$ref) {

    my $ar=shift @$ref;

    # name/value pair
    my $k=$ar->[0];
    my $v=$ar->[1];

    # prohibit redeclaration
    if(fpass()) {
      $self->haselem($k,1);

    };

    # 'i' is offset in bytes
    # mask is derived from element size
    my $shf=$i*8;

# ---   *   ---   *   ---
# first pass || root block decl:
#  >create ptr instance
#  >save reference to elems

    if(fpass() || $bypass) {

      if(!$bypass) {$v=$self;};
      $self->elems->{$k}=peso::ptr::nit(

        $k,$self->ances,
        $j,$gran,$shf,$type,
        $elem_sz,$v

      );

# ---   *   ---   *   ---
# second pass:
#  >get ptr
#  >assign value

    } else {

      $self->setv(
        $self->ances."\@$k",$v

      );
    };

# ---   *   ---   *   ---
# go to next element when 'i' equals
# or exceeds 64-bit bound and
# elems are pending in ref

    $i+=$elem_sz;
    if($i>=($line_sz/2) && @$ref) {

      # reserve a new unit
      # grow block on first pass
      if(fpass()) {
        peso::ptr::nunit();

      };$j++;$i=0;

    };
  };

};

# ---   *   ---   *   ---
# in: name,value
# sets value at offset

sub setv {

  my $self=shift;
  my $name=shift;
  my $value=shift;

  peso::ptr::fetch($name)
    ->setv($value);

};

# ---   *   ---   *   ---
# in: name to fetch
# returns stored value

sub getv {

  my $self=shift;
  my $name=shift;

  return peso::ptr::fetch($name)->getv();

};

# ---   *   ---   *   ---
# in: name to fetch
# returns addr assoc with name

sub getloc {

  my $self=shift;
  my $name=shift;

  return peso::ptr::fetch($name)->addr;

};

# ---   *   ---   *   ---
# recursive name solver

sub refsolve_rec {

  my $node=shift;
  my $pesonames=peso::decls::names;

  my $is_ptr=peso::ptr::valid($node->val);
  my $is_name=$node->val=~ m/${pesonames}*/;

# ---   *   ---   *   ---

  if($is_name || $is_ptr) {

    if(fpass()) {
      return;

    } elsif($is_ptr) {
      $node->{-VAL}=$node->val->addr;

    };

# ---   *   ---   *   ---

  } else {
    for my $leaf(@{$node->leaves}) {
      refsolve_rec($leaf);

    };

  };
};

# ---   *   ---   *   ---
# in:tree,

# block-deref
#   0|undef:common ptr
#   !0:block ptr

# solve operations in tree

sub treesolve {

  my $node=shift;
  my $type=shift;

  my $pesc=peso::decls::pesc;

  # save current cast and override
  my $wed=peso::ptr::wed('get');
  if($type) {peso::ptr::wed($type);};

# ---   *   ---   *   ---
# iter tree

  for my $leaf(@{$node->leaves},$node) {

    # skip $:escaped;>
    if($leaf->val=~ m/${pesc}/) {
      next;

    };

    # solve/fetch non-numeric values
    if(!($leaf->val=~ m/^[0-9]+/)) {
      refsolve_rec($leaf);
      $leaf->collapse();

    };

  };

# ---   *   ---   *   ---
# restore cast and dereference pointers

  ptrderef_rec($node);
  $node->collapse();

  peso::ptr::wed($wed);

};

# ---   *   ---   *   ---
# in: tree
# recursively solve pointer dereferences

sub ptrderef_rec {

  my $node=shift;

# ---   *   ---   *   ---
# value is ptr dereference

  if($node->val eq '[') {

    my $leaf=$node->leaves->[0];
    my $is_ptr=peso::ptr::valid($leaf->val);

    if($is_ptr) {
      $node->{-VAL}=$leaf->val->getv();

    } else {
      $node->{-VAL}
        =peso::ptr::fetch($leaf->val)->getv();

    };$node->pluck(@{$node->leaves});

# ---   *   ---   *   ---
# not a pointer derefernce: go to next level

  } else {

    for my $leaf(@{$node->leaves}) {
      ptrderef_rec($leaf);

    };
  };

};

# ---   *   ---   *   ---
# prints out block

sub prich {

  my $self=shift;
  my $v_lines='';

  my @data=();

  printf '<'.$self->ances.">\n";
  my $wed=peso::ptr::wed('get');
  peso::ptr::wed(undef);

# ---   *   ---   *   ---
# get names and offsets

  { my %h=%{$self->elems};
    my @ar=();

    # iter keys out of order
    for my $ptr(values %h) {

      my $idex=$ptr->idex()*8;
      $idex=$idex+int($ptr->shf()/8);

      # stack elems & data ordered
      $ar[$idex]=[

        $ptr->lname,
        $ptr->idex,
        $ptr->shf,
        $ptr->bytesz

      ];

    };

# ---   *   ---   *   ---
# forget undefined (empty) elems

    while(@ar) {

      my $v=shift @ar;
      if(!defined $v) {next;};

      push @data,$v;

    };

  };

# ---   *   ---   *   ---

  # accumulators
  my $last_idex=undef;
  my $unit=0x00;
  my $unit_names='';

  # iter list
  while(@data) {

    my $ref=shift @data;
    my ($name,$i,$shf,$sz)=@{$ref};

# ---   *   ---   *   ---
# unit switch

    if(defined $last_idex) {
      if($last_idex!=$i) {
        $v_lines.=sprintf
          "  0x%.16X %s\n",
          $unit,$unit_names;

        $unit=0x00;
        $unit_names='';

      };

# ---   *   ---   *   ---
# accumulate

    };$last_idex=$i;
    $unit=peso::ptr::MEM->[$i];
    $unit_names="$name($sz) ".$unit_names;

  };

# ---   *   ---   *   ---
# append leftovers

  $v_lines.=sprintf
    "  0x%.16X %s\n",
    $unit,$unit_names;

  printf $v_lines."\n";
  for my $child(@{$self->children}) {
    $child->prich();

  };peso::ptr::wed($wed);

};

# ---   *   ---   *   ---
1; # ret
