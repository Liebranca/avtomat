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

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

# ---   *   ---   *   ---
# info

  our $VERSION=v2.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# force size params for ptr to value

sub mask_to($self,$type) {

  my $frame=$self->{frame};

  my $wed=$frame->wed('get');
  $frame->wed($type);

  my $mask=$self->{mask};
  my $elem_sz=$self->{elem_sz};

  $frame->wedcast($self->{shf},\$mask,\$elem_sz);
  $frame->wed($wed);

  $self->{ptr_mask}=$mask;
  $self->{ptr_elem_sz}=$elem_sz;

  return;

};

# ---   *   ---   *   ---
# check value is an instance of this class

sub valid($ptr) {return arstd::valid($ptr)};

# ---   *   ---   *   ---
# dereference ptr

sub getv($self) {

  my $frame=$self->{frame};
  my $out=undef;

# ---   *   ---   *   ---
# catch nullptr

  if($self->{addr} eq $NULL
  || $self->{addr} eq $FREEBLOCK

  ) {

    arstd::errout(
      "Can't read from %s (null ptr)\n",

      args=>[$self->{gname}],
      lvl=>$FATAL,

    );goto FAIL;

  };

# ---   *   ---   *   ---
# decode ptr

  my $elem_sz=$self->bytesz;
  my $mask=$self->{mask};

  # handle type-casts
  $frame->wedcast($self->{shf},\$mask,\$elem_sz);

  # retrieve value
  my $value=(

    $frame->{mem}->[$self->{idex}]
    &$self->{mask}

  )>>$self->{shf};

# ---   *   ---   *   ---
# check cross-unit reads

  while($mask && !($mask&0xFF)) {
    $mask=$mask>>8;

  };my $idex=$self->{idex};

  COUNT:my $i=masksz($mask);

# ---   *   ---   *   ---
# bytes read less than expected

  if($i<$elem_sz) {

    $elem_sz-=$i;$idex++;

    # get remain from next unit
    $mask=(1<<($elem_sz*8))-1;
    my $rem=$frame->{mem}->[$idex];

# ---   *   ---   *   ---
# no more bytes in data

    if(!defined $rem) {

      arstd::errout(
        'Out of bounds read at ',

        calls=>[\&prich,[$self,errout=>1]],
        lvl=>$FATAL,

      );goto FAIL;

    };

# ---   *   ---   *   ---
# get masked value at new offset

    $value|=($rem&$mask)<<($i*8);

    if($elem_sz) {goto COUNT;};

  };

# ---   *   ---   *   ---
# give:
#
#   >value on success
#   >undef on failure

DONE:
  $out=$value;

FAIL:
  return $out;

};

# ---   *   ---   *   ---
# write to addr

sub setv($self,$value) {

  my $frame=$self->{frame};
  my $out=undef;

# ---   *   ---   *   ---
# catch nullptr

  if($self->{addr} eq $NULL
  || $self->{addr} eq $FREEBLOCK

  ) {

    arstd::errout(
      "Can't write to %s (null ptr)\n",

      args=>[$self->{gname}],
      lvl=>$FATAL,

    );goto FAIL;

  };

# ---   *   ---   *   ---
# ensure we dont overwrite a pointer's
# size attributes

  my $elem_sz=$self->bytesz;
  my $mask=$self->{mask};

  if(

     $frame->valid_addr($value)
  && $self->{type} eq 'unit'

  ) {

    $elem_sz=$self->{ptr_elem_sz};

    $value&=0xFFFFFFFF;
    $value|=$elem_sz<<32;
    $value|=$MEMPTR;

  };

# ---   *   ---   *   ---

  if($value eq $NULL) {

    if($self->{idex}%16) {
      $frame->{mem}->[$self->{idex}]=$NULL;

    };

    goto DONE;

  };

# ---   *   ---   *   ---

  # handle type-casts
  $frame->wedcast($self->{shf},\$mask,\$elem_sz);

  # clear bits at offset
  $frame->{mem}->[$self->{idex}]&=~$mask;

  # set value
  $frame->{mem}->[$self->{idex}]|=(
    ($value<<$self->{shf})&$mask

  );

# ---   *   ---   *   ---
# check cross-unit writes

  while($mask && !($mask&0xFF)) {
    $mask=$mask>>8;

  };

  my $idex=$self->{idex};
  COUNT:my $i=masksz($mask);

# ---   *   ---   *   ---
# bytes read less than expected

  if($i<$elem_sz) {

    $value=$value>>($i*8);
    $elem_sz-=$i;$idex++;

    # get remain from next unit
    $mask=(1<<($elem_sz*8))-1;
    my $addr=\($frame->{mem}->[$idex]);

# ---   *   ---   *   ---
# no more bytes in data

    if(!defined $$addr) {

      arstd::errout(
        'Out of bounds write at ',

        calls=>[\&prich,[$self,errout=>1]],
        lvl=>$FATAL,

      );goto FAIL;

    };

# ---   *   ---   *   ---
# set masked value at new offset

    $$addr&=~$mask;
    $$addr|=($value&$mask);

    if($elem_sz) {goto COUNT;};

  };

# ---   *   ---   *   ---
# give:
#
#   >1 on success
#   >undef on failure

DONE:
  $out=1;

FAIL:
  return $out;

};

# ---   *   ---   *   ---
# get raw address

sub byteoff($self) {
  return $self->{idex}+($self->{shf}/8);

};

# ---   *   ---   *   ---
# move backwards one block-offset

sub mprev_scope($self,$step) {

  my $frame=$self->{frame};
  my $out=undef;

# ---   *   ---   *   ---
# index into previou scope

  my $idex
    =$frame->{scopes}
    ->{$self->{scope}}
    ->{_beg}-1;

# ---   *   ---   *   ---
# get scope

  my $scope=$frame->{scopes}->{
    $frame->{tab}->[$idex]

  };if($idex<0 || !defined $scope) {
    goto FAIL;

  };

# ---   *   ---   *   ---
# get ptr in scope

  my $neigh=$scope->{_itab}->[
    @{$scope->{_itab}}+$step

  ];

# ---   *   ---   *   ---
# catch out-of-bounds

FAIL:

  if(!defined $neigh) {
    arstd::errout(
      'Can\'t jump to ',

      calls=>[\&prich,[$self,errout=>1]],
      lvl=>$FATAL,

    );

  } else {
    $out=$neigh;

  };

  return $out;

};

# ---   *   ---   *   ---
# move forward one block+offset

sub mnext_scope($self,$step)  {

  my $frame=$self->{frame};
  my $out=undef;

# ---   *   ---   *   ---
# index into next scope

  my $idex

    =$frame->{scopes}
    ->{$self->{scope}}
    ->{_end}+1;

# ---   *   ---   *   ---
# get name of scope

  my $key=$frame->{tab}->[$idex];
  if(!defined $key) {
    goto FAIL;

  };

# ---   *   ---   *   ---
# get scope

  my $scope=$frame->{scopes}->{$key};
  if(!defined $scope) {
    goto FAIL;

  # get ptr in scope
  };my $neigh=$scope->{_itab}->[$step];

# ---   *   ---   *   ---
# catch out-of-bounds

FAIL:

  if(!defined $out) {
    arstd::errout(
      'Can\'t jump to ',

      calls=>[\&prich,[$self,errout=>1]],
      lvl=>$FATAL,

    );

  } else {
    $out=$neigh;

  };

  return $out;

};

# ---   *   ---   *   ---
# go to neighboring *named* ptr

sub move($self,$step) {

  my $frame=$self->{frame};

  my $idex=$self->{slot}+$step;

  my $scope=$frame->{scopes}->{$self->{scope}};
  my $neigh=undef;

# ---   *   ---   *   ---
# catch negative indexing

  if($idex<0) {
    goto FAIL;

# ---   *   ---   *   ---
# try to get ptr at index

  };$neigh

    =$scope

    ->{_itab}
    ->[$idex];

# ---   *   ---   *   ---
# attempted read was out of bounds

  FAIL:if(!defined $neigh) {

    # go to prev scope
    if($idex<0) {
      $step+=$self->{slot};
      $neigh=$self->mprev_scope($step);

    # go to next scope
    } else {
      $step-=@{$scope->{_itab}}-$self->{slot};
      $neigh=$self->mnext_scope($step);

    };
  };return $neigh;
};

# ---   *   ---   *   ---
# navigation shorthands

# get next *named* ptr
sub mnext($self) {return $self->move(1)};

# get prev *named* ptr
sub mprev($self) {return $self->move(-1)};

# addr +/- offset
sub leap($self,$step) {
  return $self->fetch($self->{addr}+$step);

};

# ---   *   ---   *   ---
# store instance for later fetch

sub save($self) {

  my $frame=$self->{frame};
  my $lang=$frame->{master}->{lang};

# ---   *   ---   *   ---
# redecl guard

  if($frame->gname_declared($self)) {

    arstd::errout(
      "Redeclaration of symbol <%s>\n",

      args=>[$self->{gname}],
      lvl=>$FATAL,

    );

  };

# ---   *   ---   *   ---
# create new hash if need

  if(!$frame->scope_declared($self->{scope})) {
    $frame->declscope($self->{scope},$self->{idex});


# ---   *   ---   *   ---
# append to inner tab if ptr is named

  } elsif($lang->valid_name(
      $self->{lname}

  )) {

    # save top of stack
    $self->{slot}

    =@{$frame->{scopes}
      ->{$self->{scope}}
      ->{_itab}

    };

    # now add to it
    push

    @{$frame->{scopes}
      ->{$self->{scope}}
      ->{_itab}

    },$self;

# ---   *   ---   *   ---
# save ptr at path@to@ptr

  };$frame->{scopes}

    ->{$self->{scope}}
    ->{$self->{lname}}

  =$self;

# ---   *   ---   *   ---
# JIC metadata for funky scenarios

  # save ptr at stringified addr(!!!)
  $frame->{addrs}->{$self->{addr}}=$self;

  # to help locate scope for anon ptrs
  $frame->{tab}->[$self->{idex}]=$self->{scope};

  # check if unit index is higher than
  # the last recorded increment
  if(

    $frame->{scopes}
      ->{$self->{scope}}
      ->{_end}

    <$self->{idex}

  ) {

    # adjust scope boundary
    $frame->{scopes}
      ->{$self->{scope}}
      ->{_end}=$self->{idex}+1;

  };

  return;

};

# ---   *   ---   *   ---
# constructors

sub new_frame($m) {
  return peso::ptr::frame::create($m);

};

# ---   *   ---   *   ---

sub nit($frame,%args) {

  $args{gname}=($args{scope} ne $args{lname})
    ? $args{scope}.q{@}.$args{lname}
    : $args{lname}
    ;

  my $bytesz=masksz($args{mask});
  $args{mask}=$args{mask} << $args{shf};

# ---   *   ---   *   ---
# create instance

  my $ptr=bless {

    slot=>0,
    frame=>$frame,

    addr=>

      $MEMPTR

    | ($bytesz<<32)
    | ($args{idex}<<3)
    | ($args{shf}/8),

    %args,

  },'peso::ptr';

# ---   *   ---   *   ---
# save does some book-keeping...

  $ptr->save();
  return $ptr;

};

# ---   *   ---   *   ---
# ^ same, but for anonymous ptrs

sub anonnit($frame,$addr) {

  # get fetch metadata
  my ($idex,$shf,$mask,$elem_sz)
    =@{$frame->decode($addr)};

  # find scope assoc with addr
  my $scope=$frame->addr_to_scope($addr);

  my $blk
    =$frame->{scopes}
    ->{$scope}->{_itab}
    ->[0]->{blk}

  ;

# ---   *   ---   *   ---
# create instance

  my $ptr=bless {

    # ya right
    lname=>$addr,
    gname=>$addr,
    addr=>$addr,

    scope=>$scope,

    slot=>-1,
    idex=>$idex,
    mask=>$mask,
    type=>'anon',

    shf=>$shf,

    elem_sz=>$elem_sz,
    blk=>$blk,

    frame=>$frame,

  },'peso::ptr';

# ---   *   ---   *   ---

  $ptr->save();

  if(!exists $frame->{addrs}->{$addr}) {
    $frame->{addrs}->{$addr}=$ptr;

  };return $ptr;

};

# ---   *   ---   *   ---
# derive bytesize from mask

sub masksz($mask) {

  my $sz=0;

  # count bytes
  while($mask) {
    $mask=$mask>>8;$sz++;

  };return $sz;

};

sub bytesz($self) {

  # shift to start of unit
  my $mask=$self->{mask}>>$self->{shf};
  return masksz($mask);

};

# ---   *   ---   *   ---

sub prich($self,%opt) {

  # opt defaults
  $opt{errout}//=0;

# ---   *   ---   *   ---
# get pointer info

  my $refaddr="$self";
  $refaddr=~ m/HASH[(](0x[0-9-a-f]+)[)]/;
  $refaddr=${^CAPTURE[0]};

  $refaddr=~ s/0x//;
  $refaddr=uc($refaddr);

# ---   *   ---   *   ---
# select filehandle

  my $FH=($opt{errout})
    ? *STDERR
    : *STDOUT
    ;

# ---   *   ---   *   ---
# spit it out

  return

  printf {$FH} sprintf(

    "\n<0x%s>\n\n".

    "  TYPE %12s%s\n".
    "  NAME %12s%s\n\n".
    "  ADDR %12s%s\n\n".

    "  VALUE%12s%s\n".

    "\n",

    $refaddr,

    q{ },$self->{type},
    q{ },$self->{gname},
    q{ },(sprintf '%016X',$self->{addr}),
    q{ },$self->{blk},

  );

};

# ---   *   ---   *   ---
# bit of a mngr class

package peso::ptr::frame;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

# ---   *   ---   *   ---
# constructors

;;sub nit($frame,@args) {
  return peso::ptr::nit($frame,@args);

};sub anonnit($frame,@args) {
  return peso::ptr::anonnit($frame,@args);

};

sub create($master) {

  my $frame=bless {

    mem=>[],
    tab=>[],
    wed=>undef,

    addrs=>{},
    scopes=>{},

    lscope=>[],
    lscope_names=>[],

    master=>$master,

  },'peso::ptr::frame';

  $frame->declscope('non',0);

  return $frame;

};

# ---   *   ---   *   ---
# grow MEM by some amount
# amount is assumed NOT to be aligned

sub nunit($frame,$mult) {

  my $types=$frame->{master}->{lang}->{types};

  my $alignment=$types->{unit}->{size}*$mult;
  my $half_sz=$types->{half}->{size};

# ---   *   ---   *   ---
# grow to a multiple of alignment

  my $i=0;
  while(!int($i/$alignment)) {
    push @{$frame->{mem}},$FREEBLOCK;
    $i+=$half_sz;

  };

  return $alignment;

};

# ---   *   ---   *   ---
# in: (frame) type
# set/unset type-casting mode

sub wed($frame,$w) {

  my $lang=$frame->{master}->{lang};
  my $types=$lang->{types};

  if(!defined $w) {
    $frame->{wed}=undef;

  } elsif(exists $types->{$w}) {
    $frame->{wed}=$w;

  };return $frame->{wed};

};

# ---   *   ---   *   ---
# addr can be fetched without a segfault

sub valid_addr($frame,$addr) {

  my $out=0;

# ---   *   ---   *   ---
# catch nullptr

  if(

     $addr eq $NULL
  || $addr eq $FREEBLOCK

  || !($addr=~ m/^[0-9]+$/)

  ) {

    goto TAIL;

  };

# ---   *   ---   *   ---
# addr is registered

  if($frame->is_named_ptr($addr)) {

    $out=1;
    goto TAIL;

  };

# ---   *   ---   *   ---
# ufff, Jesus Christ...
#
#   > absolute idex of ptr is defined
#
#   AND
#
#   > addr has correct signature
#     (look at $MEMPTR under style.pm)
#
#   AND
#
#   > addr has a non-zero value on it's
#     size byte
#
# ^if all of that is true, check passed
# holy shit why do we even allow anon pointers??

  my $data=$frame->decode($addr);
  if(

     (defined $frame->{mem}->[$data->[0]])

  && (($addr& $MEMPTR) eq $MEMPTR)

  && ($addr& $MEMPTR_SZBYTE)

  ) {

    $out=1;

  };

# ---   *   ---   *   ---

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# in: (frame) name,idex
# declare an empty block

sub declscope($frame,$name,$idex) {

  $frame->{scopes}->{$name}={

      # we use these values to navigate
      # pointer arrays through next/prev

      _beg=>$idex,
      _end=>$idex+1,

      _itab=>[],

    };

  return;

};

# ---   *   ---   *   ---
# in: address
# decode fetch directions

sub decode($frame,$addr) {

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

sub fetch($frame,$key) {

  my $lang=$frame->{master}->{lang};

  my $ptr;
  if($frame->valid_addr($key)) {
    $ptr=$frame->addr_lookup($key);

  } else {
    $ptr=$frame->name_lookup($key);

  };return $ptr;

};

# ---   *   ---   *   ---
# find scope to which memory index
# belongs to. used for navigation

sub addr_to_scope($frame,$addr) {

  if($addr eq $NULL) {
    return 'non';

  };my $idex=($addr&0xFFFFFFFF)>>3;

# ---   *   ---   *   ---
# backtrack or fail

  while(!defined $frame->{tab}->[$idex]) {

    $idex--;

    if($idex<0) {
      arstd::errout(
        "Can't find scope for address %016X\n",

        args=>[$addr],
        lvl=>$FATAL,

      );

    };

  };return $frame->{tab}->[$idex];

};

# ---   *   ---   *   ---
# decl checks

# check name in local scope
sub name_in_lscope($frame,$name) {

  my $i=0;
  my $out=undef;

# ---   *   ---   *   ---
# iter current namespace

  for my $scope(@{$frame->{lscope}}) {

    # found, save && end loop
    if(exists $scope->{$name}) {
      $out=$frame->{lscope}->[$i];
      last;

    };$i++;
  };

# ---   *   ---   *   ---
# give undef on failure

  return $out;

# ---   *   ---   *   ---
# check global name declared

};sub gname_declared($frame,$obj) {

  my $out=0;

  if(exists $frame->{scopes}->{$obj->{scope}}) {

    $out=exists

      $frame->{scopes}
        ->{$obj->{scope}}
        ->{$obj->{lname}}

    ;
  };

  return $out;

# ---   *   ---   *   ---
# check namespace declared

};sub scope_declared($frame,$name) {
  return exists $frame->{scopes}->{$name};

# check name assoc with addr
};sub is_named_ptr($frame,$addr) {
  return exists $frame->{addrs}->{$addr};

# ---   *   ---   *   ---
# THIS ONE LOOKS LIKE ITS LEGACY CODE
# I NEVER AGAIN USED AND COMPLETELY FORGOT
# IT EVEN EXISTED
#
# i'll decide if I still need it later...

};sub is_block_ref($frame,$name) {
  return exists $frame->{scopes}->{$name};

};

# ---   *   ---   *   ---
# find element by address
# local and global scope

sub addr_lookup($frame,$key) {

  my $out=undef;
  if(!$frame->is_named_ptr($key)) {
    $out=$frame->anonnit($key);

  } else {
    $out=$frame->{addrs}->{$key};

  };

  return $out;

};

# ---   *   ---   *   ---
# swap out current local scope

sub setscope($frame,@names) {

  $frame->{lscope_names}=[];
  $frame->{lscope}=[];

  while(@names) {
    my $name=shift @names;

# ---   *   ---   *   ---
# catch no such scope

    if(!$frame->scope_declared($name)) {

      arstd::errout(
        "Namespace <%s> not declared\n",

        args=>[$name],
        lvl=>$FATAL,

      );

    };

# ---   *   ---   *   ---
# append to local scope list

    push @{$frame->{lscope}},
      $frame->{scopes}->{$name};

    push @{$frame->{lscope_names}},$name;

  };return;

};

# ---   *   ---   *   ---
# in: (frame)
#
#   offset in bits
#   reference to bitmask
#   reference to elem_sz
#
# manages type-casting

sub wedcast($frame,$shf,$maskref,$szref) {

  my $lang=$frame->{master}->{lang};
  my $types=$lang->{types};

# ---   *   ---   *   ---
# skip when no casting

  if(!defined $frame->{wed}) {
    goto TAIL;

  };

# ---   *   ---   *   ---

  # get size from type
  my $elem_sz=$types->{$frame->{wed}}->size;
  my $i=$shf/8;

  # build mask from size
  my $gran=(1<<($elem_sz*8))-1;
  $$maskref=$gran<<$shf;
  $$szref=$elem_sz;

# ---   *   ---   *   ---

TAIL:
  return;

};

# ---   *   ---   *   ---
# name solving methods

# look for name in local scopes array

sub lname_lookup($frame,$key) {

  my $m=$frame->master;
  my $scope=undef;

# ---   *   ---   *   ---
# report bad name fetch

  if(

  !defined(
    $scope=$frame->name_in_lscope($key)

  ) && !$m->fpass()
  ) {

    arstd::errout(

      "Name <%s> not in local scope:\n".

      ' >'.
      (join "\n >",@{$frame->{lscope_names}}).

      "\n",

      args=>[$key],
      lvl=>$FATAL,

    );

  };return $scope->{$key};

# ---   *   ---   *   ---
# look for full name,ie non@mod@sub...

};sub gname_lookup($frame,$key) {

  my @ar=split m/[@]/,$key;

  if($ar[0] ne 'non') {
    unshift @ar,'non';

  };

  my $lname=pop @ar;
  my $scope=join q{@},@ar;

  return $frame->{scopes}->{$scope}->{$lname};

};

# ---   *   ---   *   ---
# find elements by name
# local and global scopes

sub name_lookup($frame,$key) {

  # @ sign marks mod@sub@elem key-type
  my $ptr=[\&lname_lookup,\&gname_lookup]

    ->[$key=~ m/@/]
    ->($frame,$key);

  return $ptr;

};

# ---   *   ---   *   ---
1; # ret
