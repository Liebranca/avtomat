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

# ---   *   ---   *   ---
# global state

my %CACHE=(

  -MEM=>[],
  -TAB=>[],

  -ADDRS=>{},
  -SCOPES=>{},

  -LSCOPE=>undef,

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

sub shf {return (shift)->{-SHF};};
sub elem_sz {return (shift)->{-ELEM_SZ};};

# ---   *   ---   *   ---

sub value {

  my $self=shift;return (
    MEM->[$self->idex]
    &$self->mask

  )>>$self->shf;

};

# ---   *   ---   *   ---

sub addr {

  my $self=shift;
  return

     ($self->bytesz<<32)

    |($self->idex<<3)
    |($self->shf/8);

};

sub move {

  my $self=shift;
  my $step=shift;
  my $idex=$self->slot+$step;

  my $scope=SCOPES->{$self->scope};
  my $neigh=undef;

# ---   *   ---   *   ---

  if($idex<0) {
    goto FAIL;

  };$neigh

    =$scope

    ->{-ITAB}
    ->[$idex];

# ---   *   ---   *   ---

  FAIL:if(!defined $neigh) {

    if($idex<0) {

      $step+=$self->slot;
      $idex=$scope->{-BEG}-1;

      if($idex<0) {
        err_oob();

      };

      $scope=SCOPES->{TAB->[$idex]};
      $neigh=$scope->{-ITAB}->[
        @{$scope->{-ITAB}}+$step

      ];

# ---   *   ---   *   ---

    } else {

      $step-=@{$scope->{-ITAB}}-$self->slot;

      $idex=$scope->{-END}+1;
      $scope=SCOPES->{TAB->[$idex]};

      if(!defined $scope) {
        err_oob();

      };

      $neigh=$scope->{-ITAB}->[$step];

    };
  };return $neigh;

};

# ---   *   ---   *   ---
# swap out current local scope

sub setscope {

  my $name=shift;

  # errchk
  if(!scope_declared($name)) {

    printf "Namespace <$name> not declared\n";
    exit;

  };$CACHE{-LSCOPE}=SCOPES->{$name};

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

    SCOPES
      ->{$self->scope}

      ={

        # we use these values to navigate
        # pointer arrays through next/prev

        -BEG=>$self->idex,
        -END=>$self->idex+1,

        -ITAB=>[$self],

      };$self->{-SLOT}=0;

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
  return exists LSCOPE->{(shift)};

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

# check namespace declared
};sub scope_declared {

  my $name =shift;
  return exists SCOPES->{$name};

# check name assoc with addr
};sub is_named_ptr {

  my $addr=shift;
  return exists ADDRS->{"$addr"};

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
    $type,$elem_sz,$value,

    $set

  )=@_;my $gname=$scope.'@'.$lname;

# ---   *   ---   *   ---
# set bits and return already existing

  if($set) {

    MEM->[$idex]|=($value&$mask)<<$shf;

    if(defined(
      my $ptr=name_lookup($gname)

    )) {return SCOPES->{$scope}->{$lname};};

  };$mask=$mask<<$shf;

# ---   *   ---   *   ---
# create instance

  my $ptr=bless {

    -LNAME=>$lname,
    -GNAME=>$gname,
    -SCOPE=>$scope,

    -SLOT=>-1,
    -IDEX=>$idex,
    -MASK=>$mask,
    -TYPE=>$type,

    -SHF=>$shf,

    -ELEM_SZ=>$elem_sz,

  },'peso::ptr';

# ---   *   ---   *   ---

  $ptr->save();
  return $ptr;

};

# ---   *   ---   *   ---
# ^ same, but for anonymous ptrs

sub anonnit {

  my $addr=shift;

  my ($idex,$shf,$mask,$elem_sz)
    =@{decode($addr)};

  my $scope=idex_to_scope($idex);

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

  },'peso::ptr';

# ---   *   ---   *   ---

  $ptr->save();
  return $ptr;

};

# ---   *   ---   *   ---
# derive bytesize from mask

sub bytesz {

  my $self=shift;

  # shift to start of unit
  my $mask=$self->mask>>$self->shf;
  my $sz=0;

  # count bytes
  while($mask) {
    $mask=$mask>>8;$sz++;

  };return $sz;

};

# ---   *   ---   *   ---

sub lname_lookup {

  my $key=shift;

  if(!name_in_lscope($key)) {

    printf "$key\n";
    exit;

  };return LSCOPE->{$key};

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

# in: name to fetch
# returns byte offsets assoc with name

sub fetch {

  my $key=shift;
  my $ptr;

  my $pesonames=peso::defs::names;

  if($key=~ m/${pesonames}*/) {
    $ptr=name_lookup($key);

  } else {
    $ptr=addr_lookup($key);

  };return $ptr;

#  if($CACHE{-WED}) {
#    $mask=wedcast($shf);
#
#  };
#
#  my $sz=0;
#  $mask=$mask>>$shf;
#
#  while($mask) {
#    $mask=$mask>>8;$sz++;
#
#  };
#
## ---   *   ---   *   ---
#
#  # encode fetch directions
#  my $ptr=($sz<<32)|($idex<<3)|($shf/8);
#  return $ptr;

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

# in: ptr
# gets value at saved fetch directions
sub getptrv {

  my $self=shift;
  my $ptr=shift;

  # get ptr data
  my ($idex,$shf,$mask,$elem_sz)
    =@{decptr(undef,$ptr)};

# ---   *   ---   *   ---

  # fetch unit
  my $value=MEM->[$idex];

  # get masked value at offset
  $value&=$mask;
  $value=$value>>$shf;

# ---   *   ---   *   ---

  # count mask bytes
  COUNT:my $i=0;
  $mask=$mask>>$shf;
  if($mask) {while($mask) {
    $mask=$mask>>8;$i++;

  }} else {$i=$elem_sz;};

  # bytes read less than expected
  if($i<$elem_sz) {
    $elem_sz-=$i;$idex++;

    # get remain from next unit
    $mask=(1<<($elem_sz*8))-1;
    my $rem=$CACHE{-DATA}->[$idex];

    # no more bytes in data
    if(!defined $rem) {

      printf sprintf
        'Out of bounds read at PE addr '.
        "<0x%.016X>\n",$ptr;

      return $value;

    };

    # get masked value at new offset
    $value|=($rem&$mask)<<($i*8);

    if($elem_sz) {goto COUNT;};

  };

  return $value;

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
