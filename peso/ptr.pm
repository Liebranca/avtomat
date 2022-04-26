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

  use lib $ENV{'ARPATH'}.'/lib/';
  use peso::defs;

  use Scalar::Util qw/blessed/;

# ---   *   ---   *   ---
# global state

my %CACHE=(

  -MEM=>[],
  -TAB=>[],
  -WED=>undef,

  -ADDRS=>{},
  -SCOPES=>{},

  -LSCOPE=>[],
  -LSCOPE_NAMES=>[],

);$CACHE{-TYPES}=join(
    '|',keys %{peso::defs::sizes()}

);

# ---   *   ---   *   ---
# getters

sub MEM {return $CACHE{-MEM};};
sub TAB {return $CACHE{-TAB};};

sub ADDRS {return $CACHE{-ADDRS};};
sub SCOPES {return $CACHE{-SCOPES};};
sub LSCOPE {return $CACHE{-LSCOPE};};

sub lname {return (shift)->{-LNAME};};
sub gname {return (shift)->{-GNAME};};
sub type {return (shift)->{-TYPE};};
sub idex {return (shift)->{-IDEX};};
sub mask {return (shift)->{-MASK};};
sub scope {return (shift)->{-SCOPE};};
sub slot {return (shift)->{-SLOT};};
sub blk {return (shift)->{-BLK};};

sub shf {return (shift)->{-SHF};};
sub elem_sz {return (shift)->{-ELEM_SZ};};

# ---   *   ---   *   ---
# check value is an instance of this class

sub valid {

  my $ptr=shift;if(

     blessed($ptr)
  && $ptr->isa('peso::ptr')

  ) {

    return 1;
  };return 0;

};

# ---   *   ---   *   ---
# dereference ptr

sub value {

  my $self=shift;

  my $elem_sz=$self->bytesz;
  my $mask=$self->mask>>$self->shf;

  # handle type-casts
  wedcast($self->shf,\$mask,\$elem_sz);

  # retrieve value
  my $value=(

    MEM->[$self->idex]
    &$self->mask

  )>>$self->shf;

# ---   *   ---   *   ---
# check cross-unit reads

  $mask=$self->mask>>$self->shf;
  my $idex=$self->idex;

  COUNT:my $i=masksz($mask);

# ---   *   ---   *   ---
# bytes read less than expected

  if($i<$elem_sz) {

    $elem_sz-=$i;$idex++;

    # get remain from next unit
    $mask=(1<<($elem_sz*8))-1;
    my $rem=MEM->[$idex];

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

sub setv {

  my $self=shift;
  my $value=shift;

  my $elem_sz=$self->bytesz;
  my $mask=$self->mask>>$self->shf;

  # handle type-casts
  wedcast($self->shf,\$mask,\$elem_sz);

  # clear bits at offset
  MEM->[$self->idex]&=~$mask;

  # set value
  MEM->[$self->idex]|=(
    ($value<<$self->shf)&$mask

  );

# ---   *   ---   *   ---
# check cross-unit writes

  if($mask>$self->mask>>$self->shf) {
    $mask=$self->mask>>$self->shf;

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
    my $addr=\(MEM->[$idex]);

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

sub addr {

  my $self=shift;
  return

     ($self->bytesz<<32)

    |($self->idex<<3)
    |($self->shf/8);

};

# ---   *   ---   *   ---
# move backwards one block-offset

sub mprev_scope {

  my $self=shift;
  my $step=shift;

# ---   *   ---   *   ---

  my $idex
    =SCOPES
    ->{$self->scope}
    ->{-BEG}-1;

  # get scope
  my $scope=SCOPES->{TAB->[$idex]};
  if($idex<0 || !defined $scope) {
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

sub mnext_scope  {

  my $self=shift;
  my $step=shift;

# ---   *   ---   *   ---

  my $idex

    =SCOPES
    ->{$self->scope}
    ->{-END}+1;

  # get name of scope
  my $key=TAB->[$idex];
  if(!defined $key) {
    goto FAIL;

  };

# ---   *   ---   *   ---

  # get scope
  my $scope=SCOPES->{$key};
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

sub move {

  my $self=shift;
  my $step=shift;
  my $idex=$self->slot+$step;

  my $scope=SCOPES->{$self->scope};
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
sub mnext {
  my $self=shift;
  return $self->move(1);

# get prev *named* ptr
};sub mprev {
  my $self=shift;
  return $self->move(-1);

# addr +/- offset
};sub leap {
  my $self=shift;
  my $step=shift;

  return fetch($self->addr+$step);

};

# ---   *   ---   *   ---
# swap out current local scope

sub setscope {

  my @names=@_;

  $CACHE{-LSCOPE_NAMES}=[];
  $CACHE{-LSCOPE}=[];

  while(@names) {

    my $name=shift @names;

    # errchk
    if(!scope_declared($name)) {

      printf "Namespace <$name> not declared\n";
      exit;

    };

    push @{$CACHE{-LSCOPE}},SCOPES->{$name};
    push @{$CACHE{-LSCOPE_NAMES}},$name;

  };

};

# ---   *   ---   *   ---
# in: type
# set/unset type-casting mode

sub wed {

  my $w=shift;

  if(!defined $w) {
    $CACHE{-WED}=undef;

  } elsif($w=~ m/${CACHE{-TYPES}}/) {
    $CACHE{-WED}=$w;

  };return $CACHE{-WED};

};

# ---   *   ---   *   ---
# in:
#
#   offset in bits
#   reference to bitmask
#   reference to elem_sz
#
# manages type-casting

sub wedcast {

  my $shf=shift;
  my $maskref=shift;
  my $szref=shift;

  # skip when no casting
  if(!defined $CACHE{-WED}) {
    return;

  };

  # get size from type
  my $elem_sz=peso::defs::sizes
    ->{$CACHE{-WED}};

  my $i=$shf/8;

  # build mask from size
  my $gran=(1<<($elem_sz*8))-1;
  $$maskref=$gran<<$shf;
  $$szref=$elem_sz;

};

# ---   *   ---   *   ---
# in: name,idex
# declare an empty block

sub declscope {

  my $name=shift;
  my $idex=shift;

  SCOPES
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
# store instance for later fetch

sub save {

  my $self=shift;
  my $pesonames=peso::defs::names;

  # redecl guard
  if($self->gname_declared()) {

    printf

      "Redeclaration of symbol <".
      $self->gname.">\n";

    exit;

  };

# ---   *   ---   *   ---
# create new hash if need

  if(!scope_declared($self->scope)) {
    declscope($self->scope,$self->idex);


# ---   *   ---   *   ---

  # append to inner tab if ptr is named
  } elsif($self->lname=~ m/${pesonames}*/) {

    # save top of stack
    $self->{-SLOT}

    =@{SCOPES
      ->{$self->scope}
      ->{-ITAB}

    };

    # now add to it
    push

    @{SCOPES
      ->{$self->scope}
      ->{-ITAB}

    },$self;

# ---   *   ---   *   ---

  # save ptr at path@to@ptr
  };SCOPES

    ->{$self->scope}
    ->{$self->lname}

  =$self;

# ---   *   ---   *   ---
# JIC metadata for funky scenarios

  # save ptr at stringified addr(!!!)
  ADDRS->{(sprintf "%s",$self->addr)}
  =$self;

  # to help locate scope for anon ptrs
  TAB->[$self->idex]=$self->scope;

  # check if unit index is higher than
  # the last recorded increment
  if(

    SCOPES
      ->{$self->scope}
      ->{-END}

    <$self->idex

  ) {

    # adjust scope boundary
    SCOPES
      ->{$self->scope}
      ->{-END}=$self->idex+1;

  };

};

# ---   *   ---   *   ---
# find scope to which memory index
# belongs to. used for navigation

sub idex_to_scope {

  my $idex=shift;
  while(!defined TAB->[$idex]) {

    $idex--;

    if($idex<0) {
      err_oob();

    };

  };return TAB->[$idex];

};

# ---   *   ---   *   ---
# decl checks

# check name in local scope
sub name_in_lscope {

  my $name=shift;
  my $i=0;

  # iter current namespace
  for my $scope(@{LSCOPE()}) {

    if(exists $scope->{$name}) {
      goto FOUND;

    };$i++;

  };return undef;
  FOUND:return LSCOPE->[$i];

# check global name declared
};sub gname_declared {

  my $self=shift;
  if(!exists SCOPES->{$self->scope}) {
    return 0;

  };return(

    exists

    SCOPES
      ->{$self->scope}
      ->{$self->lname}

  );

# ---   *   ---   *   ---
# check namespace declared

};sub scope_declared {

  my $name =shift;
  return exists SCOPES->{$name};

# check name assoc with addr
};sub is_named_ptr {

  my $addr=shift;
  return exists ADDRS->{"$addr"};

# check ptr is block reference
};sub is_block_ref {

  my $name=shift;
  return exists SCOPES->{$name};

};

# ---   *   ---   *   ---

sub err_oob {
  printf "OUT OF BOUNDS\n";
  exit;

};

# ---   *   ---   *   ---
# memory ops

sub nunit {push @{MEM()},0x00;};

# ---   *   ---   *   ---
# constructor

sub nit {

  my (

    $lname,$scope,

    $idex,$mask,$shf,
    $type,$elem_sz,$blk,

    $set

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

  },'peso::ptr';

# ---   *   ---   *   ---

  $ptr->save();
  return $ptr;

};

# ---   *   ---   *   ---
# ^ same, but for anonymous ptrs

sub anonnit {

  my $addr=shift;

  # get fetch metadata
  my ($idex,$shf,$mask,$elem_sz)
    =@{decode($addr)};

  # find scope assoc with addr
  my $scope=idex_to_scope($idex);

  my $blk=SCOPES->{$scope}->{-ITAB}->[0]->blk;

# ---   *   ---   *   ---
# create instance

  my $ptr=bless {

    -LNAME=>$addr,
    -GNAME=>$addr,
    -SCOPE=>$scope,

    -SLOT=>-1,
    -IDEX=>$idex,
    -MASK=>$mask,
    -TYPE=>wed('get'),

    -SHF=>$shf,

    -ELEM_SZ=>$elem_sz,
    -BLK=>$blk,

  },'peso::ptr';

# ---   *   ---   *   ---

  $ptr->save();
  return $ptr;

};

# ---   *   ---   *   ---
# derive bytesize from mask

sub masksz {

  my $mask=shift;
  my $sz=0;

  # count bytes
  while($mask) {
    $mask=$mask>>8;$sz++;

  };return $sz;

}

sub bytesz {

  my $self=shift;

  # shift to start of unit
  my $mask=$self->mask>>$self->shf;
  return masksz($mask);

};

# ---   *   ---   *   ---
# name solving methods

sub lname_lookup {

  my $key=shift;
  my $scope=undef;

  if(!defined ($scope=name_in_lscope($key))) {

    printf

      "Name <$key> not in local scope:\n".

      ' >'.
      (join "\n >",@{$CACHE{-LSCOPE_NAMES}}).

      "\n";

    exit;

  };return $scope->{$key};

};sub gname_lookup {

  my $key=shift;
  my @ar=split '@',$key;

  if($ar[0] ne 'non') {
    unshift @ar,'non';

  };

  my $lname=pop @ar;
  my $scope=join '@',@ar;

  return SCOPES->{$scope}->{$lname};

};

# ---   *   ---   *   ---
# find elements by name
# local and global scopes

sub name_lookup {

  my $key=shift;

  # @ sign marks mod@sub@elem key-type
  my $ptr=[\&lname_lookup,\&gname_lookup]

    ->[$key=~ m/@/]
    ->($key);

  return $ptr;

};

# ---   *   ---   *   ---
# find element by address
# local and global scope

sub addr_lookup {

  my $key=shift;

  if(!is_named_ptr($key)) {
    return anonnit($key);

  };return ADDRS->{$key};

};

# ---   *   ---   *   ---
# in: name/addr to fetch
# get ptr instance from name/addr

sub fetch {

  my $key=shift;
  my $ptr;

  my $pesonames=peso::defs::names;

  if($key=~ m/${pesonames}*/) {
    $ptr=name_lookup($key);

  } else {
    $ptr=addr_lookup($key);

  };return $ptr;

};

# ---   *   ---   *   ---
# in: address
# decode fetch directions

sub decode {

  my $addr=shift;

  my $elem_sz=$addr>>32;
  my $idex=($addr&0xFFFFFFFF)>>3;
  my $shf=($addr&7)*8;

  my $mask=(1<<($elem_sz*8))-1;
  $mask=$mask<<$shf;

  return [$idex,$shf,$mask,$elem_sz];

};

# ---   *   ---   *   ---

sub prich {

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
1; # ret
