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
  my %PESO=do 'peso/defs.ph';

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

  };

# ---   *   ---   *   ---

my %CACHE=(

  -SELF=>undef,
  -WED=>undef,
  -BLOCKS=>{},
  -DATA=>[],

  -PENDING=>[],

  -TYPES=>join '|',keys %{$PESO{-SIZES}},

);

# in: block name
# errchk and get root block
sub clan {

  my $key=shift;
  if($key eq 'self') {
    return $CACHE{-SELF};

  } elsif(!exists $CACHE{-BLOCKS}->{$key}) {

    printf "No root block named '$key'\n";
    exit;

  };return $CACHE{-BLOCKS}->{$key};

};

# in: block instance
# scope to block
sub setscope {$CACHE{-SELF}=shift;};

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

  my $blk=bless {

    -NAME=>$name,
    -SIZE=>0,

    -PAR=>$self,
    -ELEMS=>{},
    -ATTRS=>$attrs,

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

    };$CACHE{-BLOCKS}->{$name}=$blk;

  };

# placeholder!
# add block data into this line
push @{$CACHE{-DATA}},0xFFFFFFFF;

  return $blk;

};

# ---   *   ---   *   ---

# getters
sub name {return (shift)->{-NAME};};
sub elems {return (shift)->{-ELEMS};};
sub par {return (shift)->{-PAR};};
sub data {return $CACHE{-DATA};};
sub size {return (shift)->{-SIZE};};
sub attrs {return (shift)->{-ATTRS};};

# find ancestors recursively
sub ances {

  my $self=shift;
  my $name=$self->name;

  if($self->par) {
    $name=$self->par->ances().'@'.$name;

  };return $name;

};

# ---   *   ---   *   ---

sub wat {printf ''.(
  join "\n",@{$CACHE{-PENDING}}

)."\n";};

# in: element name, redecl guard
# errcheck for bad fetch

sub haselem {

  my $self=shift;
  my $name=shift;
  my $redecl=shift;

  if(

     !exists $self->elems->{$name}
  && !defined $redecl

  ) {

$self->elems->{$name}=[0,0,0,8];
push @{ $CACHE{-PENDING} },$self->ances.'@'.$name;
return;

    printf "Block <".$self->ances.'> '.
      "has no member named '".$name."'\n";

    exit;

# ---   *   ---   *   ---

  } elsif(

     exists $self->elems->{$name}
  && defined $redecl

  ) {

    printf "Redeclaration of '$name' ".
      'at block <'.$self->ances.">\n";

    exit;

  };

};

# ---   *   ---   *   ---

# in: type
# set/unset typing mode
sub wed {

  my $w=shift;

  if(!defined $w) {
    $CACHE{-WED}=undef;

  } elsif($w=~ m/${CACHE{-TYPES}}/) {
    $CACHE{-WED}=$w;

  };return $CACHE{-WED};

};

# in: offset in bits
# gives wed-sized mask
sub wedcast {

  my $shf=shift;

  my $elem_sz=$PESO{-SIZES}
    ->{$CACHE{-WED}};

  my $i=$shf/8;

  my $gran=(1<<($elem_sz*8))-1;
  return $gran<<$shf;

};

# ---   *   ---   *   ---

# in: array of [key,value] references,
# in: data type

# inserts new elements into block

sub expand {

  my $self=shift;
  my $ref=shift;
  my $type=shift;

  # set type of var for all ops
  $CACHE{-WED}=$type;

  # get size from type, in bytes
  my $elem_sz=$PESO{-SIZES}->{$type};
  $self->{-SIZE}+=@$ref*$elem_sz;

  # 'line' is two units
  # 'unit' is 64-bit chunk
  # we use these as minimum size for blocks
  my $line_sz=$PESO{-SIZES}->{'line'};
  my $gran=(1<<($elem_sz*8))-1;

# ---   *   ---   *   ---

  # save top of stack
  my $j=@{$self->data};
  push @{$self->data},0x00;

  # push elements to data
  my $i=0;while(@$ref) {

    my $ar=shift @$ref;

    # name/value pair
    my $k=$ar->[0];
    my $v=$ar->[1];

    # prohibit redeclaration
    $self->haselem($k,1);

    # 'i' is offset in bytes
    # mask is derived from element size
    my $shf=$i*8;
    my $mask=$gran<<$shf;

    # shift v to next avail place
    # within current 64-bit unit
    $v=$v<<$shf;

# ---   *   ---   *   ---

    # save fetch metadata to elems
    # value goes into data
    $self->elems->{$k}=[$j,$shf,$mask,$type];
    $self->data->[$j]|=$v;

    # go to next element
    $i+=$elem_sz;

    # 'i' equals or exceeds 64-bit bound
    # and elems pending in ref
    if($i>=($line_sz/2) && @$ref) {

      # reserve a new unit
      push @{ $self->data },0x00;
      $j++;$i=0;

    };

  };

};

# ---   *   ---   *   ---

# in: name,value
# sets value at offset
sub setv {

  my $self=shift;

  # block is write protected
  if(!($self->attrs& O_WR)) {
    printf "block '".$self->name.
      "' cannot be written\n";

    exit;

  };

  my $name=shift;
  my $value=shift;
  my $cast=shift;

# ---   *   ---   *   ---

  # get fetch metadata
  my ($idex,$shf,$mask)=@{
    $self->elems->{$name}

  };

  # manage/alter wedded type
  if(defined $cast) {
    $CACHE{-WED}=$cast;

  };if(defined $CACHE{-WED}) {
    $mask=wedcast($shf);

  };

# ---   *   ---   *   ---

  # fit value to type mask
  $value=$value&($mask>>$shf);

  # clear out and set at shifted position
  $self->data->[$idex]&=~$mask;
  $self->data->[$idex]|=$value<<$shf;

};

# ---   *   ---   *   ---

# in: name to fetch
# returns stored value
sub getv {

  my $self=shift;
  my $name=shift;

  # check name declared
  $self->haselem($name);

# ---   *   ---   *   ---

  # get fetch metadata
  my ($idex,$shf,$mask)=@{
    $self->elems->{$name}

  };

  # alter mask to wed
  if(defined $CACHE{-WED}) {
    $mask=wedcast($shf);

  };

  # mask out to type
  my $value=$self->data->[$idex];
  $value&=$mask;

  # shift and ret
  return $value>>$shf;

};

# ---   *   ---   *   ---

# in: ptr
# decode pointer
sub decptr {

  my $self=shift;
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
  my $value=$CACHE{-DATA}->[$idex];

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

# in: ptr,value
# save to address
sub setptrv {

  my $self=shift;
  my $ptr=shift;
  my $value=shift;

  # get ptr data
  my ($idex,$shf,$mask,$elem_sz)
    =@{decptr(undef,$ptr)};

  if(defined $CACHE{-WED}) {

    $mask=wedcast($shf);
    $elem_sz=$PESO{-SIZES}->{$CACHE{-WED}};

  };

# ---   *   ---   *   ---

  # clear bytes on unit
  # adjust mask to start
  $CACHE{-DATA}->[$idex]&=~$mask;
  $mask=$mask>>$shf;

  # set cleared bytes
  $CACHE{-DATA}->[$idex]
    |=($value&$mask)<<$shf;

  # count mask bytes
  COUNT:my $i=0;
  if($mask) {while($mask) {
    $mask=$mask>>8;$i++;
    $value=$value>>8;

  }} else {$i=$elem_sz;};

  # bytes written less than expected
  if($i<$elem_sz) {

    $elem_sz-=$i;$idex++;

    # no more bytes in data
    if(!defined $CACHE{-DATA}->[$idex]) {

      printf sprintf
        'Out of bounds write at PE addr '.
        "<0x%.016X>\n",$ptr;

      return;

    };

    # set remain to next unit
    $mask=(1<<($elem_sz*8))-1;
    $CACHE{-DATA}->[$idex]&=~$mask;
    $CACHE{-DATA}->[$idex]|=$value;

    if($elem_sz) {goto COUNT;};

  };

};

# ---   *   ---   *   ---

# in: name to fetch
# returns byte offsets assoc with name

sub getloc {

  my $self=shift;
  my $name=shift;

  # errchk
  $self->haselem($name);

  # get fetch metadata
  my ($idex,$shf,$mask)=@{
    $self->elems->{$name}

  };

  # ret offsets (no mask or typedata)
  return ($idex,$shf/8);

};

# ---   *   ---   *   ---

# in: name to fetch
# returns byte offsets assoc with name

sub getptrloc {

  my $self=shift;
  my $name=shift;

  # errchk
  $self->haselem($name);

  # fetch metadata
  my ($idex,$shf,$mask)=@{
    $self->elems->{$name}

  };

  my $sz=0;
  $mask=$mask>>$shf;

  while($mask) {
    $mask=$mask>>8;$sz++;

  };

  # encode fetch directions
  my $ptr=($sz<<32)|($idex<<3)|($shf/8);
  return $ptr;

};

# ---   *   ---   *   ---+

# name solver

sub refsolve {

  my $node=shift;
  my $dst=$CACHE{-SELF};

  my $name=undef;
  my $cont=undef;

  if($node->val=~ m/@/) {

    my @path=split '@',$node->val;

    my $root=shift @path;
    my $blk=clan($root);

    while(@path>1) {
      my $key=shift @path;

      $blk->haselem($key);
      $blk=$blk->elems->{$key};

    };$name=$path[0];
    $cont=$blk;

# ---   *   ---   *   ---

  } elsif(

    $node->val()=~
    m/${PESO{-NAMES}}*/

  ) {

    $dst->haselem($node->val);

    $name=$node->val;
    $cont=$dst;

  };

  return ($cont,$name);

};

# ---   *   ---   *   ---

# recursive name solver

sub refsolve_rec {

  my $node=shift;

  if($node->val=~ m/${PESO{-NAMES}}*/) {
    my ($cont,$name)=refsolve($node);
    $node->{-VAL}=$cont->getptrloc($name);

  } else {
    for my $leaf(@{$node->leaves}) {
      refsolve_rec($leaf);

    };

  };
};

# ---   *   ---   *   ---

sub prich2 {

my $self=shift;
for my $v(@{$self->data}) {

printf sprintf "0x%.16X\n",$v;

};

};

# prints out block
sub prich {

  my $self=shift;
  my $v_lines='';

  my @data=();

# ---   *   ---   *   ---

  # get names and offsets
  { my %h=%{$self->elems};
    my @ar=();

    # iter keys out of order
    for my $k(keys %h) {

      my ($idex,$shf,$mask)=@{
        $self->elems->{$k}

      };

      # mask out to type
      my $value=$self->data->[$idex];
      $value&=$mask;

      # shift and ret
      $value=$value>>$shf;
      my $sz=0;

      # derive bytesize from mask
      $mask=$mask>>$shf;
      while($mask) {
        $mask=$mask>>8;$sz++;

      };

      # stack elems ordered
      $ar[$idex*8+($shf/8)]
        =[$k,$value,$idex,$shf,$sz];

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
    my ($name,$v,$i,$shf,$sz)=@{$ref};

    # unit switch
    if(defined $last_idex) {
      if($last_idex!=$i) {
        $v_lines.=sprintf
          "  0x%.16X %s\n",
          $unit,$unit_names;

        $unit=0x00;
        $unit_names='';

      };

    # accumulate
    };$last_idex=$i;
    $unit|=$v<<$shf;
    $unit_names="$name($sz) ".$unit_names;

  };

# ---   *   ---   *   ---

  # append leftovers
  $v_lines.=sprintf
    "  0x%.16X %s\n",
    $unit,$unit_names;

  printf $v_lines."\n";

};

# ---   *   ---   *   ---
1; # ret
