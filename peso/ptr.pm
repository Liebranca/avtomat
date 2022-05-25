#!/usr/bin/perl
# ---   *   ---   *   ---
# PTR
# Locations in memory
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::ptr;
  use strict;
  use warnings;

  use Scalar::Util qw/blessed/;

# ---   *   ---   *   ---

  use constant {

    MEMPTR=>0xFFB10C<<40,

    MEMPTR_SZBYTE=>0xFF<<32,
    MEMPTR_SZMASK=>0x08<<32,

  };use constant {
    NULL=>MEMPTR|MEMPTR_SZMASK|0x00

  };

# ---   *   ---   *   ---
# getters

sub lname {return (shift)->{-LNAME};};
sub gname {return (shift)->{-GNAME};};
sub type {return (shift)->{-TYPE};};
sub idex {return (shift)->{-IDEX};};
sub mask {return (shift)->{-MASK};};

# ---   *   ---   *   ---

sub scope {return (shift)->{-SCOPE};};
sub slot {return (shift)->{-SLOT};};
sub blk {return (shift)->{-BLK};};

sub shf {return (shift)->{-SHF};};
sub elem_sz {return (shift)->{-ELEM_SZ};};

sub frame {return (shift)->{-FRAME};};
sub master {return (shift)->frame->{-MASTER};};

# ---   *   ---   *   ---
# force size params for ptr to value

sub mask_to($$) {

  my ($self,$type)=@_;
  my $frame=$self->frame;


  my $wed=$frame->wed('get');
  $frame->wed($type);

  my $mask=$self->mask;
  my $elem_sz=$self->elem_sz;

  $frame->wedcast($self->shf,\$mask,\$elem_sz);
  $frame->wed($wed);

  $self->{-PTR_MASK}=$mask;
  $self->{-PTR_ELEM_SZ}=$elem_sz;

};

# ---   *   ---   *   ---
# check value is an instance of this class

sub valid($) {

  my $ptr=shift;if(

     blessed($ptr)
  && $ptr->isa('peso::ptr')

  ) {

    return 1;
  };return 0;

};

# ---   *   ---   *   ---
# dereference ptr

sub getv($) {

  my ($self)=@_;
  my $frame=$self->frame;

  if($self->addr eq NULL) {

    printf
      "Can't read from %s (null ptr)\n",
      $self->gname;

    return 0;

  };

  my $elem_sz=$self->bytesz;
  my $mask=$self->mask;

  # handle type-casts
  $frame->wedcast($self->shf,\$mask,\$elem_sz);

  # retrieve value
  my $value=(

    $frame->MEM->[$self->idex]
    &$self->mask

  )>>$self->shf;

# ---   *   ---   *   ---
# check cross-unit reads

  while($mask && !($mask&0xFF)) {
    $mask=$mask>>8;

  };my $idex=$self->idex;

  COUNT:my $i=masksz($mask);

# ---   *   ---   *   ---
# bytes read less than expected

  if($i<$elem_sz) {

    $elem_sz-=$i;$idex++;

    # get remain from next unit
    $mask=(1<<($elem_sz*8))-1;
    my $rem=$frame->MEM->[$idex];

# ---   *   ---   *   ---
# no more bytes in data

    if(!defined $rem) {

      printf
        'Out of bounds read at PE addr <'.
        $self->gname.

      ">\n";

      return 0;

    };

# ---   *   ---   *   ---
# get masked value at new offset

    $value|=($rem&$mask)<<($i*8);

    if($elem_sz) {goto COUNT;};

  };return $value;

};

# ---   *   ---   *   ---
# write to addr

sub setv($$) {

  my ($self,$value)=@_;
  my $frame=$self->frame;

  if($self->addr eq NULL) {

    printf
      "Can't write to %s (null ptr)\n",
      $self->gname;

    return;

  };

  my $elem_sz=$self->bytesz;
  my $mask=$self->mask;

# ---   *   ---   *   ---
# ensure we dont overwrite a pointer's
# size attributes

  if(

     $frame->valid_addr($value)
  && $self->type eq 'unit'

  ) {

    $elem_sz=$self->{-PTR_ELEM_SZ};

    $value&=0xFFFFFFFF;
    $value|=$elem_sz<<32;
    $value|=MEMPTR;

  };

# ---   *   ---   *   ---

  # handle type-casts
  $frame->wedcast($self->shf,\$mask,\$elem_sz);

  # clear bits at offset
  $frame->MEM->[$self->idex]&=~$mask;

  # set value
  $frame->MEM->[$self->idex]|=(
    ($value<<$self->shf)&$mask

  );

# ---   *   ---   *   ---
# check cross-unit writes

  while($mask && !($mask&0xFF)) {
    $mask=$mask>>8;

  };

  my $idex=$self->idex;
  COUNT:my $i=masksz($mask);

# ---   *   ---   *   ---
# bytes read less than expected

  if($i<$elem_sz) {

    $value=$value>>($i*8);
    $elem_sz-=$i;$idex++;

    # get remain from next unit
    $mask=(1<<($elem_sz*8))-1;
    my $addr=\($frame->MEM->[$idex]);

# ---   *   ---   *   ---
# no more bytes in data

    if(!defined $$addr) {

      printf
        'Out of bounds write at PE addr <'.
        $self->gname.

      ">\n";

      return 0;

    };

# ---   *   ---   *   ---
# set masked value at new offset

    $$addr&=~$mask;
    $$addr|=($value&$mask);

    if($elem_sz) {goto COUNT;};

  };return $value;

};

# ---   *   ---   *   ---
# get raw address

sub addr($) {

  my $self=shift;

  return

    MEMPTR

    |($self->bytesz<<32)

    |($self->idex<<3)
    |($self->shf/8);

};

# ---   *   ---   *   ---
# move backwards one block-offset

sub mprev_scope($$) {

  my ($self,$step)=@_;
  my $frame=$self->frame;

# ---   *   ---   *   ---

  my $idex
    =$frame->SCOPES
    ->{$self->scope}
    ->{-BEG}-1;

  # get scope
  my $scope=$frame->SCOPES->{
    $frame->TAB->[$idex]

  };if($idex<0 || !defined $scope) {
    goto FAIL;

  };

# ---   *   ---   *   ---
# get ptr in scope

  my $neigh=$scope->{-ITAB}->[
    @{$scope->{-ITAB}}+$step

  ];if(!defined $neigh) {
    goto FAIL;

  };

  return $neigh;
  FAIL:err_oob();

};

# ---   *   ---   *   ---
# move forward one block+offset

sub mnext_scope($$)  {

  my ($self,$step)=@_;
  my $frame=$self->frame;

# ---   *   ---   *   ---

  my $idex

    =$frame->SCOPES
    ->{$self->scope}
    ->{-END}+1;

  # get name of scope
  my $key=$frame->TAB->[$idex];
  if(!defined $key) {
    goto FAIL;

  };

# ---   *   ---   *   ---
# get scope

  my $scope=$frame->SCOPES->{$key};
  if(!defined $scope) {
    goto FAIL;

  };

# ---   *   ---   *   ---
# get ptr in scope

  my $neigh=$scope->{-ITAB}->[$step];
  if(!defined $neigh) {
    goto FAIL;

  };

  return $neigh;
  FAIL:err_oob();

};

# ---   *   ---   *   ---
# go to neighboring *named* ptr

sub move($$) {

  my ($self,$step)=@_;
  my $frame=$self->frame;

  my $idex=$self->slot+$step;

  my $scope=$frame->SCOPES->{$self->scope};
  my $neigh=undef;

# ---   *   ---   *   ---
# no negative indexing

  if($idex<0) {
    goto FAIL;

  # try to get ptr at index
  };$neigh

    =$scope

    ->{-ITAB}
    ->[$idex];

# ---   *   ---   *   ---
# attempted read was out of bounds

  FAIL:if(!defined $neigh) {

    # go to prev scope
    if($idex<0) {
      $step+=$self->slot;
      $neigh=$self->mprev_scope($step);

    # go to next scope
    } else {
      $step-=@{$scope->{-ITAB}}-$self->slot;
      $neigh=$self->mnext_scope($step);

    };
  };return $neigh;

};

# ---   *   ---   *   ---
# navigation shorthands

# get next *named* ptr
sub mnext($) {
  my $self=shift;
  return $self->move(1);

# get prev *named* ptr
};sub mprev($) {
  my $self=shift;
  return $self->move(-1);

# addr +/- offset
};sub leap($$) {

  my ($self,$step)=@_;
  return $self->fetch($self->addr+$step);

};

# ---   *   ---   *   ---
# store instance for later fetch

sub save($) {

  my $self=shift;
  my $frame=$self->frame;

  # redecl guard
  if($frame->gname_declared($self)) {

    printf

      "Redeclaration of symbol <".
      $self->gname.">\n";

    exit;

  };

# ---   *   ---   *   ---
# create new hash if need

  if(!$frame->scope_declared($self->scope)) {
    $frame->declscope($self->scope,$self->idex);


# ---   *   ---   *   ---
# append to inner tab if ptr is named

  } elsif($self->lang->valid_name(
      $self->lname

  )) {

    # save top of stack
    $self->{-SLOT}

    =@{$frame->SCOPES
      ->{$self->scope}
      ->{-ITAB}

    };

    # now add to it
    push

    @{$frame->SCOPES
      ->{$self->scope}
      ->{-ITAB}

    },$self;

# ---   *   ---   *   ---
# save ptr at path@to@ptr

  };$frame->SCOPES

    ->{$self->scope}
    ->{$self->lname}

  =$self;

# ---   *   ---   *   ---
# JIC metadata for funky scenarios

  # save ptr at stringified addr(!!!)
  $frame->ADDRS->{$self->addr}
  =$self;

  # to help locate scope for anon ptrs
  $frame->TAB->[$self->idex]=$self->scope;

  # check if unit index is higher than
  # the last recorded increment
  if(

    $frame->SCOPES
      ->{$self->scope}
      ->{-END}

    <$self->idex

  ) {

    # adjust scope boundary
    $frame->SCOPES
      ->{$self->scope}
      ->{-END}=$self->idex+1;

  };

};

# ---   *   ---   *   ---

sub err_oob {
  printf "OUT OF BOUNDS\n";
  exit;

};

# ---   *   ---   *   ---
# memory ops

sub nunit($) {

  my $frame=shift;
  push @{$frame->MEM()},0x00;

};

# ---   *   ---   *   ---
# constructors

sub new_frame($) {peso::ptr::frame::create(shift);};

sub nit($@) {

  my $frame=shift;my (

    $lname,$scope,

    $idex,$mask,$shf,
    $type,$elem_sz,$blk,

  )=@_;

  my $gname=($scope ne $lname)
    ? $scope.'@'.$lname
    : $lname;

  $mask=$mask<<$shf;

# ---   *   ---   *   ---
# create instance

  my $ptr=bless {

    -LNAME=>$lname,
    -GNAME=>$gname,
    -SCOPE=>$scope,

    -SLOT=>0,
    -IDEX=>$idex,
    -MASK=>$mask,
    -TYPE=>$type,

    -SHF=>$shf,

    -ELEM_SZ=>$elem_sz,
    -BLK=>$blk,

    -FRAME=>$frame,

  },'peso::ptr';

# ---   *   ---   *   ---

  $ptr->save();
  return $ptr;

};

# ---   *   ---   *   ---
# ^ same, but for anonymous ptrs

sub anonnit($$) {

  my ($frame,$addr)=@_;

  # get fetch metadata
  my ($idex,$shf,$mask,$elem_sz)
    =@{$frame->decode($addr)};

  # find scope assoc with addr
  my $scope=$frame->addr_to_scope($addr);

  my $blk
    =$frame->SCOPES
    ->{$scope}->{-ITAB}
    ->[0]->blk

  ;

# ---   *   ---   *   ---
# create instance

  my $ptr=bless {

    -LNAME=>$addr,
    -GNAME=>$addr,
    -SCOPE=>$scope,

    -SLOT=>-1,
    -IDEX=>$idex,
    -MASK=>$mask,
    -TYPE=>'anon',

    -SHF=>$shf,

    -ELEM_SZ=>$elem_sz,
    -BLK=>$blk,

    -FRAME=>$frame,

  },'peso::ptr';

# ---   *   ---   *   ---

  $ptr->save();

  if(!exists $frame->ADDRS->{$addr}) {
    $frame->ADDRS->{$addr}=$ptr;

  };return $ptr;

};

# ---   *   ---   *   ---
# derive bytesize from mask

sub masksz($) {

  my $mask=shift;
  my $sz=0;

  # count bytes
  while($mask) {
    $mask=$mask>>8;$sz++;

  };return $sz;

};

sub bytesz($) {

  my $self=shift;

  # shift to start of unit
  my $mask=$self->mask>>$self->shf;
  return masksz($mask);

};

# ---   *   ---   *   ---

sub prich($) {

  my $self=shift;

  my $refaddr="$self";
  $refaddr=~ m/HASH\((0x[0-9-a-f]+)\)/;
  $refaddr=$1;

  $refaddr=~ s/0x//;
  $refaddr=uc($refaddr);

# ---   *   ---   *   ---

  printf sprintf(

    "\n<0x%s>\n\n".

    "  TYPE:%12s%s\n".
    "  NAME:%12s%s\n\n".
    "  ADDR:%12s%s\n".

    "\n",

    $refaddr,

    ' ',$self->type,
    ' ',$self->gname,
    ' ',(sprintf "%016X",$self->addr)

  );

};

# ---   *   ---   *   ---
# bit of a mngr class

package peso::ptr::frame;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use peso::decls;

# ---   *   ---   *   ---
# getters

sub MEM {return (shift)->{-MEM};};
sub TAB {return (shift)->{-TAB};};
sub ADDRS {return (shift)->{-ADDRS};};
sub SCOPES {return (shift)->{-SCOPES};};
sub LSCOPE {return (shift)->{-LSCOPE};};

# ---   *   ---   *   ---
# constructors

sub nit($@) {peso::ptr::nit(@_);};

sub create($) {

  my ($master)=@_;

  return bless {

    -MEM=>[],
    -TAB=>[],
    -WED=>undef,

    -ADDRS=>{},
    -SCOPES=>{},

    -LSCOPE=>[],
    -LSCOPE_NAMES=>[],

#    -TYPES=>join(
#      '|',keys %{$master->lang->sizes()}
#
#    ),

    -MASTER=>$master,

  },'peso::ptr::frame';

};

# ---   *   ---   *   ---
# in: (frame) type
# set/unset type-casting mode

sub wed($$) {

  my ($frame,$w)=@_;
  my $lang=$frame->master->lang;

  my $types=$lang->types;

  if(!defined $w) {
    $frame->{-WED}=undef;

  } elsif(exists $types->{$w}) {
    $frame->{-WED}=$w;

  };return $frame->{-WED};

};

# ---   *   ---   *   ---
# addr can be fetched without a segfault

sub valid_addr($$) {

  my ($frame,$addr)=@_;

  if($addr eq peso::ptr->NULL) {
    return 0;

  };

  if($frame->is_named_ptr($addr)) {
    return 1;

  };

  my $data=$frame->decode($addr);
  if(

     defined $frame->MEM->[$data->[0]]

  && (

      ($addr& peso::ptr->MEMPTR)
      eq peso::ptr->MEMPTR

  ) && ($addr& peso::ptr->MEMPTR_SZBYTE)

  ) {
    return 1;

  };return 0;

};

# ---   *   ---   *   ---
# in: (frame) name,idex
# declare an empty block

sub declscope($$$) {

  my ($frame,$name,$idex)=@_;

  $frame->SCOPES
    ->{$name}

    ={

      # we use these values to navigate
      # pointer arrays through next/prev

      -BEG=>$idex,
      -END=>$idex+1,

      -ITAB=>[],

    };

};

# ---   *   ---   *   ---
# in: address
# decode fetch directions

sub decode($$) {

  my ($frame,$addr)=@_;

  my $elem_sz=($addr>>32)&0xFF;
  my $idex=($addr&0xFFFFFFFF)>>3;
  my $shf=($addr&7)*8;

  my $mask=(1<<($elem_sz*8))-1;
  $mask=$mask<<$shf;

  return [$idex,$shf,$mask,$elem_sz];

};

# ---   *   ---   *   ---
# in: name/addr to fetch
# get ptr instance from name/addr

sub fetch($$) {

  my ($frame,$key)=@_;
  my $lang=$frame->master->lang;

  my $ptr;

  if($lang->valid_name($key)) {
    $ptr=$frame->name_lookup($key);

  } else {
    $ptr=$frame->addr_lookup($key);

  };return $ptr;

};

# ---   *   ---   *   ---
# find scope to which memory index
# belongs to. used for navigation

sub addr_to_scope($$) {

  my ($frame,$addr)=@_;

  if($addr eq peso::ptr->NULL) {
    return 'non';

  };my $idex=($addr&0xFFFFFFFF)>>3;

  while(!defined $frame->TAB->[$idex]) {

    $idex--;

    if($idex<0) {
      err_oob();

    };

  };return $frame->TAB->[$idex];

};

# ---   *   ---   *   ---
# decl checks

# check name in local scope
sub name_in_lscope($$) {

  my ($frame,$name)=@_;
  my $i=0;

  # iter current namespace
  for my $scope(@{$frame->LSCOPE()}) {

    if(exists $scope->{$name}) {
      goto FOUND;

    };$i++;

  };return undef;
  FOUND:return $frame->LSCOPE->[$i];

# ---   *   ---   *   ---
# check global name declared

};sub gname_declared($$) {

  my ($frame,$obj)=@_;

  if(!exists $frame->SCOPES->{$obj->scope}) {
    return 0;

  };return(

    exists

    $frame->SCOPES
      ->{$obj->scope}
      ->{$obj->lname}

  );

# ---   *   ---   *   ---
# check namespace declared

};sub scope_declared($$) {

  my ($frame,$name)=@_;
  return exists $frame->SCOPES->{$name};

# check name assoc with addr
};sub is_named_ptr($$) {

  my ($frame,$addr)=@_;
  return exists $frame->ADDRS->{$addr};

# check ptr is block reference
};sub is_block_ref($$) {

  my ($frame,$name)=@_;
  return exists $frame->SCOPES->{$name};

};

# ---   *   ---   *   ---
# find element by address
# local and global scope

sub addr_lookup($$) {

  my ($frame,$key)=@_;

  if(!$frame->is_named_ptr($key)) {
    return $frame->anonnit($key);

  };return $frame->ADDRS->{$key};

};

# ---   *   ---   *   ---
# swap out current local scope

sub setscope($@) {

  my $frame=shift;
  my @names=@_;

  $frame->{-LSCOPE_NAMES}=[];
  $frame->{-LSCOPE}=[];

  while(@names) {

    my $name=shift @names;

    # errchk
    if(!$frame->scope_declared($name)) {

      printf "Namespace <$name> not declared\n";
      exit;

    };

    push @{$frame->{-LSCOPE}},SCOPES->{$name};
    push @{$frame->{-LSCOPE_NAMES}},$name;

  };

};

# ---   *   ---   *   ---
# in: (frame)
#
#   offset in bits
#   reference to bitmask
#   reference to elem_sz
#
# manages type-casting

sub wedcast($$$$) {

  my $frame=shift;
  my ($shf,$maskref,$szref)=@_;

  my $lang=$frame->master->lang;
  my $types=$lang->types;

  # skip when no casting
  if(!defined $frame->{-WED}) {
    return;

  };

  # get size from type
  my $elem_sz=$types->{$frame->{-WED}}->size;
  my $i=$shf/8;

  # build mask from size
  my $gran=(1<<($elem_sz*8))-1;
  $$maskref=$gran<<$shf;
  $$szref=$elem_sz;

};

# ---   *   ---   *   ---
# name solving methods

# look for name in local scopes array

sub lname_lookup($$) {

  my ($frame,$key)=@_;
  my $scope=undef;

  if(!defined (

      $scope
        =$frame->name_in_lscope($key)

  )) {

    printf

      "Name <$key> not in local scope:\n".

      ' >'.
      (join "\n >",@{$frame->{-LSCOPE_NAMES}}).

      "\n";

    exit;

  };return $scope->{$key};

# ---   *   ---   *   ---
# look for full name,ie non@mod@sub...

};sub gname_lookup($$) {

  my ($frame,$key)=@_;
  my @ar=split '@',$key;

  if($ar[0] ne 'non') {
    unshift @ar,'non';

  };

  my $lname=pop @ar;
  my $scope=join '@',@ar;

  return $frame->SCOPES->{$scope}->{$lname};

};

# ---   *   ---   *   ---
# find elements by name
# local and global scopes

sub name_lookup($$) {

  my ($frame,$key)=@_;

  # @ sign marks mod@sub@elem key-type
  my $ptr=[\&lname_lookup,\&gname_lookup]

    ->[$key=~ m/@/]
    ->($frame,$key);

  return $ptr;

};

# ---   *   ---   *   ---
1; # ret
