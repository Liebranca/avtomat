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
  use lib $ENV{'ARPATH'}.'/avtomat/';
  use stack;

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

    # pretty hexspeak
    FREEBLOCK=>0xF9EEB10C,

  };

# ---   *   ---   *   ---

my %CACHE=(

  -SELF=>undef,
  -SOIL=>undef,

  -WED=>undef,
  -BLOCKS=>undef,
  -DATA=>[],

  -TYPES=>join '|',keys %{$PESO{-SIZES}},

  -INS=>[],
  -INS_KEY=>{},
  -INS_ARR=>[],

  -NXINS=>0,
  -ENTRY=>'nit',

  -NODES=>[],
  -PASS=>0,
  -DPTR=>[],

);

# in: block name
# errchk and get root block
sub clan {

  my $key=shift;
  if($key eq 'self') {
    return $CACHE{-SELF};

  } elsif($key eq 'non') {
    return $CACHE{-SOIL};

  } elsif(!exists $CACHE{-BLOCKS}->{$key}) {

    printf "No root block named '$key'\n";
    exit;

  };return $CACHE{-BLOCKS}->{$key};

};

# in: block instance
# scope to block
sub setscope {$CACHE{-SELF}=shift;};

# ---   *   ---   *   ---

# we have to load the instruction set
# from an external hash for complex reasons
# i can make it all internal later (maybe)

sub loadins {

  my $ref=shift;my $i=0;
  for my $key(keys %$ref) {
    push @{$CACHE{-INS}},$ref->{$key}->[1];
    $CACHE{-INS_KEY}->{$key}=$i;$i++;

  };

# get idex of instruction
};sub getinsi {

  my $name=shift;$name=~ s/\s*$//;
  return $CACHE{-INS_KEY}->{$name};

};sub setnode {

  my $node=shift;

  push @{$CACHE{-NODES}},$node;
  return int(@{$CACHE{-NODES}})-1;

};sub getnode {

  my $idex=shift;
  return $CACHE{-NODES}->[$idex];

};

# ---   *   ---   *   ---

sub ex {

  my $entry=$CACHE{-ENTRY};
  my $non=$CACHE{-SOIL};

  wed(undef);

  $entry=bgetptrv(undef,$entry);
  setnxins($entry->insid);

  while(!(nxins()<0)) {
    $entry=$entry->exnext();

    if(nxins()<0) {last;};

  };

};

sub exfetnx {

  my $self=shift;
  my $i=nxins();

  if($i<0) {return (undef,undef,undef);};

  my $nx=sprintf "_%.08i",$i;

  my $ins='ins'.$nx;
  my $arg='arg'.$nx;

  if(!exists $self->elems->{$ins}) {
    $self=getinsid($i);

  };

  return ($self,$ins,$arg);

};sub getinsid {

  my $i=shift;
  my $blk=$CACHE{-INS_ARR}->[$i];

  if(!defined $blk) {

    printf "EX_END: instruction fetch fail!\n";
    exit;

  };return $blk;

};

sub exnext {

  my $self=shift;
  my $i=nxins();

  my ($ins,$arg)=(0,0);

  ($self,$ins,$arg)=$self->exfetnx();
  if(!defined $self) {return;};

  $ins=$self->getv($ins);
  $arg=$self->getv($arg);

  $arg=getnode($arg);
  my $ori=$arg;
  $arg=$arg->dup();

  $CACHE{-INS}->[$ins]->($arg);

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

    -ELEMS=>{},
    -ATTRS=>$attrs,
    -INSID=>$insid,

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

    };

    $self=$CACHE{-SOIL};

# ---   *   ---   *   ---

  };if($name ne 'non') {
    $self->addchld($blk);

  };

  if($insid>=0) {
    $CACHE{-INS_ARR}->[$insid]=$blk;

  };

  return $blk;

};

# initialize global root
$CACHE{-SOIL}=nit(undef,'non');
$CACHE{-BLOCKS}=$CACHE{-SOIL}->{-ELEMS};

# ---   *   ---   *   ---

sub addchld {

  my $self=shift;
  my $blk=shift;

  my $i=$self->sstack->spop();

  # add block data into this line
  my @line=(

    [$blk->name,$i],

  );

# ---   *   ---   *   ---

  my $bypass=int(
    $self->name eq 'non'
  ||!$self->attrs

  );

  $self->expand(\@line,'unit',$bypass);
  $self->children->[$i]=$blk;
  $blk->{-PAR}=$self;

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

# in: element name, redecl guard
# errcheck for bad fetch

sub haselem {

  my $self=shift;
  my $name=shift;
  my $redecl=shift;

  if($name=~ m/@/) {

    my @ar=split '@',$name;
    my $blk=$self;

    while(@ar) {

      my $root=shift @ar;

      if(exists $blk->elems->{$root}) {
        $blk=$blk->bgetptrv($root);

        $name=$ar[0];
        if(@ar eq 1) {last;};

      } else {

        printf "Block <".$self->ances.'> '.
        "has no member named '".$root."'\n";

        exit;

      };

    };return ($blk,$name);

  };

# ---   *   ---   *   ---

  if(

     !exists $self->elems->{$name}
  && !defined $redecl

  ) {

    NO_ELEM:

    printf "Block <".$self->ances.'> '.
      "has no member named '".$name."'\n";

    exit;

# ---   *   ---   *   ---

  } elsif(

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

  };return ($self,$name);

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
  my $bypass=shift;

  # set type of var for all ops
  $CACHE{-WED}=$type;

  # get size from type, in bytes
  my $elem_sz=$PESO{-SIZES}->{$type};

  my $inc_size=@$ref*$elem_sz;

  # grow block on first pass
  if(fpass()) {
    $self->{-SIZE}+=$inc_size;

  };

  # 'line' is two units
  # 'unit' is 64-bit chunk
  # we use these as minimum size for blocks
  my $line_sz=$PESO{-SIZES}->{'line'};
  my $gran=(1<<($elem_sz*8))-1;

# ---   *   ---   *   ---

  my $j;

  # grow block on first pass
  if(fpass()) {

    # save top of stack
    $j=@{$self->data};
    if(!$bypass) {
      push @{$CACHE{-DPTR}},$j;

    };push @{$self->data},0x00;

  } else {
    $j=shift @{$CACHE{-DPTR}};

  };

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
    my $mask=$gran<<$shf;

    # do not set value on first pass
    if(fpass() && !$bypass) {
      $v=0;

    # on second pass:
    # shift v to next avail place
    # within current 64-bit unit
    } else {
      $v=$v<<$shf;

    };

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
      # grow block on first pass
      if(fpass()) {
        push @{ $self->data },0x00;

      };$j++;$i=0;

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

# by-name block lookup

sub blookup {

  my $self=shift;
  my $name=shift;

  if(!defined $self) {
    ($self,$name)=refsolve($name);

  };return ($self,$name);

};

# ---   *   ---   *   ---

# get block location from ptr
sub bgetptrloc {

  my $self=shift;
  my $name=shift;

  my $ptr=$self->getptrloc($name);
  $ptr=$self->getptrv($ptr);

  return ($self,$ptr);

};

# ---   *   ---   *   ---

# additional step for ptr-to-block deref
sub bgetptrv {

  my $self=shift;
  my $name=shift;

  ($self,$name)=blookup($self,$name);

  my $ptr;($self,$ptr)
    =bgetptrloc($self,$name);

  return $self->children->[$ptr];

# ---   *   ---   *   ---

# ^same, deref by ptr rather than name
};sub bderefptr {

  my $self=shift;
  my $ptr=shift;

  my $blk=undef;

  while(!defined $self->children->[$ptr]) {

    my $old=$self;
    $self=$self->par;

    if(!defined $self) {
      printf sprintf(
        "Cannot resolve ptr:%s@%X\n",
        $old->ances,$ptr

      );exit;

    };

  };$blk=$self->children->[$ptr];
  return $blk;

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
  ($self,$name)=$self->haselem($name);

  # fetch metadata
  my ($idex,$shf,$mask)=@{
    $self->elems->{$name}

  };

  if($CACHE{-WED}) {
  $mask=wedcast($shf);

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

  my $val=shift;
  my $dst=$CACHE{-SELF};

  my $name=undef;
  my $cont=undef;

  if($val=~ m/@/) {

    my @path=split '@',$val;
    if($path[0] ne 'non') {
      unshift @path,'non';

    };

    my $root=shift @path;
    my $blk=clan($root);

    while(@path>1) {
      my $key=shift @path;

      if(fpass()) {
        if(!exists $blk->elems->{$key}) {
          return (undef,undef);

        };

      } else {
        $blk->haselem($key);

      };if($blk->name ne 'non') {
        $blk=$blk->elems->{$key};

      } else {
        $blk=$blk->bgetptrv($key);

      };

    };$name=$path[0];
    $cont=$blk;

# ---   *   ---   *   ---

  } elsif(

    $val=~
    m/${PESO{-NAMES}}*/

  ) {

    while(!exists $dst->elems->{$val}) {

      $dst=$dst->par;
      if(!$dst) {

        if(fpass()) {
          return (undef,undef);

        } else {
          printf "Symbol '".
            $val.
            "' not found\n";

          exit;

        };

      };
    };

    $name=$val;
    $cont=$dst;

  };return ($cont,$name);

};

# ---   *   ---   *   ---

# recursive name solver

sub refsolve_rec {

  my $node=shift;

  if($node->val=~ m/${PESO{-NAMES}}*/) {
    my ($cont,$name)=refsolve($node->val);

    if($cont && $name) {
      $node->{-VAL}=$cont->getptrloc($name);

    };

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
  my $blk_deref=shift;
  my $type=shift;

  # save current cast and override
  my $wed=wed('get');
  if($type) {wed($type);};

# ---   *   ---   *   ---

  # iter tree
  for my $leaf(@{
    $node->leaves->[0]->leaves

  }) {

    # solve/fetch non-numeric values
    if(!($leaf->val=~ m/[0-9]+/)) {
      refsolve_rec($leaf);
      $leaf->collapse();

    };

  };

  # restore cast and dereference pointers
  wed($wed);
  ptrderef_rec($node,$blk_deref);

  # solve the entire tree
  $node->collapse();

};

# ---   *   ---   *   ---

# in:tree,is ptr to block
# recursively solve pointer dereferences

sub ptrderef_rec {

  my $node=shift;
  my $block_ptr=shift;

  $block_ptr=(!$block_ptr);

# ---   *   ---   *   ---

  # value is ptr dereference
  if($node->val eq '[') {

    # is ptr to block
    if($block_ptr) {
      $node->{-VAL}=getptrv(
        undef,
        $node->leaves->[0]->val

      );$node->{-VAL}=getptrv(
        undef,
        $node->val

      );

# ---   *   ---   *   ---

    # ptr to value
    } else {
      $node->{-VAL}=getptrv(

        undef,
        $node->leaves->[0]->val

      );

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
  for my $child(@{$self->children}) {
    $child->prich();

  };

};

# ---   *   ---   *   ---
1; # ret
