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

# ---   *   ---   *   ---
# global state

my %CACHE=(

  -MEM=>[],
  -SCOPES=>{},

  -LSCOPE=>undef,

);

# ---   *   ---   *   ---
# getters

sub MEM {return $CACHE{-MEM};};
sub SCOPES {return $CACHE{-SCOPES};};
sub LSCOPE {return $CACHE{-LSCOPE};};

sub lname {return (shift)->{-LNAME};};
sub gname {return (shift)->{-GNAME};};
sub type {return (shift)->{-TYPE};};
sub idex {return (shift)->{-IDEX};};
sub mask {return (shift)->{-MASK};};
sub scope {return (shift)->{-SCOPE};};

sub shf {return (shift)->{-SHF};};
sub elem_sz {return (shift)->{-ELEM_SZ};};

# ---   *   ---   *   ---

sub value {

  my $self=shift;return (
    MEM->[$self->idex]
    >>$self->shf)&$self->mask;

};

# ---   *   ---   *   ---

sub addr {

  my $self=shift;
  return

     ($self->bytesz<<32)

    |($self->idex<<3)
    |($self->shf/8);

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
    SCOPES->{$self->scope}={};

  # save ptr at path@to@ptr
  };SCOPES

    ->{$self->scope}
    ->{$self->lname}

  =$self;

};

# ---   *   ---   *   ---
# decl checks

# check name in local scope
sub name_in_lscope {
  return exists LSCOPE->{(shift)};

# check global name declared
};sub gname_declared {

  my $self=shift;

  return exists SCOPES
    ->{$self->scope}
    ->{$self->lname};

# check namespace declared
};sub scope_declared {

  my $name =shift;
  return exists SCOPES->{$name};

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

  )=@_;

# ---   *   ---   *   ---
# set bits and return already existing

  if($set) {
    MEM->[$idex]|=($value&$mask)<<$shf;
    return SCOPES->{$scope}->{$lname};

  };$mask=$mask<<$shf;

# ---   *   ---   *   ---
# create instance

  my $ptr=bless {

    -LNAME=>$lname,
    -GNAME=>$scope.'@'.$lname,
    -SCOPE=>$scope,

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

    exit;

  };return LSCOPE->{$key};

};sub gname_lookup {

  my $key=shift;
  my @ar=split '@',$key;

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

# in: name to fetch
# returns byte offsets assoc with name

sub fetch {

  my $key=shift;
  my $ptr=name_lookup($key);

  return $ptr;

#  # errchk
#  ($self,$name)=$self->haselem($name);
#
#  # fetch metadata
#  my ($idex,$shf,$mask)=@{
#    $self->elems->{$name}
#
#  };
#
## ---   *   ---   *   ---
#
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

# in: ptr
# decode pointer
sub decode {

  my $ptr=shift;

  my $elem_sz=$ptr>>32;
  my $idex=($ptr&0xFFFFFFFF)>>3;
  my $shf=($ptr&7)*8;

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
