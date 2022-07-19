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
package peso::blk;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

  use lang;
  use stack;

  use peso::st;

# ---   *   ---   *   ---
# info

  our $VERSION=v2.80.3;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# check value is an instance of this class

sub valid($blk) {return arstd::valid($blk)};

# ---   *   ---   *   ---
# return 64-bit representation of object
# not really implemented yet...

sub as_long($blk) {

  my $pframe=$blk->{frame}->{master}->{ptr};
  my $ptr=$pframe->fetch($blk->ances);

  $ptr=

    ($peso::st::TYPE_BLOCK)
  | ($blk->{attrs}<<16)
  | ($ptr->byteoff()<<32)

  ;

  return $ptr;

};

# ---   *   ---   *   ---
# in: name,parent,permissions
# creates a new data/instruction block

sub new_frame(@args) {
  return peso::blk::frame::create(@args);

};

# ---   *   ---   *   ---

sub nit($frame,$parent,$name,$attrs) {

  # default to all protected
  if(!defined $attrs) {
    $attrs=0b000;

  };

  my $blk=bless {

    name=>$name,
    size=>0,

    parent=>$parent,
    children=>[],
    scope=>$frame->{self},

    elems=>{},
    elems_i=>{},
    idex_base=>0,

    attrs=>$attrs,
    frame=>$frame,

  },'peso::blk';

# ---   *   ---   *   ---
# initialized from instance

  # new->setParent $self
  if(defined $parent) {
    $parent->{elems}->{$name}=$blk;

  # is root block
  } else {

# ---   *   ---   *   ---
# redecl guard

    if(exists $frame->{blocks}->{$name}) {

      arstd::errout(

        'Ilegal operation: '.
        'redeclaration of root block '.
        "'%s' at global scope\n",

        args=>[$name],
        lvl=>$FATAL,

      );

    };

    $parent=$frame->{soil};

# ---   *   ---   *   ---
# only non can be orphaned

  };if($name ne 'non') {
    $parent->addchld($blk);
    $blk->{idex_base}=int(@{
      $frame->{master}->{ptr}->{mem}

    });

  };

  return $blk;

};

# ---   *   ---   *   ---
# convenience settings for sub-blocks

sub addchld($self,$blk) {

  my $frame=$self->{frame};

  # add block data into this line
  my @line=([$blk->{name},$blk]);

# ---   *   ---   *   ---
# is root or rom

  my $bypass=int(

      $self->{name} eq 'non'
  || !$self->{attrs}

  );

# ---   *   ---   *   ---
# grow the block

  $self->expand(

    \@line,

    type=>'unit',
    bypass=>$bypass

  );

# ---   *   ---   *   ---
# book-keeping

  push @{$self->{children}},$blk;
  $blk->{parent}=$self;

  $frame->{master}->{ptr}->declscope(

    $blk->ances,
    int(@{$frame->{master}->{ptr}->{mem}})

  );

  return;

};

# ---   *   ---   *   ---
# find ancestors recursively

sub ances($self) {

  my $name=$self->{name};

  while($self->{parent}) {
    $name=$self->{parent}->{name}.q{@}.$name;
    $self=$self->{parent};

    if(!defined $self) {last};

  };

  return $name;

};

# ---   *   ---   *   ---
# in: block, element name
# lookup errme shorthand

sub no_such_elem($self,$name) {

  arstd::errout(

    'Block <%s> '.
    "has no member named '%s'\n",

    args=>[$self->ances,$name],
    lvl=>$FATAL,

  );

  return;

};

# ---   *   ---   *   ---

# in: element name, redecl guard
# errcheck for bad fetch

sub haselem($self,$name,$redecl) {

  my $fr_ptr=$self->{frame}->{master}->{ptr};

# ---   *   ---   *   ---
# solve compound name (module@sub@elem)

  if($name=~ m/@/) {
    my $blk=$fr_ptr->fetch($name)->{blk};
    $self=$blk;

# ---   *   ---   *   ---
# element not found (plain name)

  } elsif(

     !exists $self->{elems}->{$name}
  && !defined $redecl

  ) {$self->no_such_elem($name);}

# ---   *   ---   *   ---
# redeclaration guard

  elsif(

     exists $self->{elems}->{$name}
  && defined $redecl

  ) {

    # block-as-elem is exempt from redecl
    if(valid $self->{elems}->{$name}) {
      goto TAIL;

    };

# ---   *   ---   *   ---
# redecl guard

    arstd::errout(
      'Redeclaration of \'%s\''.
      "at block <%s>\n",

      args=>[$name,$self->ances],
      lvl=>$FATAL,

    );

# ---   *   ---   *   ---

  };

TAIL:
  return ($self,$name);

};

# ---   *   ---   *   ---
# in: array of [key,value] references,
# in: data type

# inserts new elements into block

sub expand($self,$ref,%args) {

  # defaults
  $args{type}//='half';
  $args{attrs}//={size=>1};
  $args{bypass}//=1;

  my ($type,$attrs,$bypass)=(
    $args{type},
    $args{attrs},
    $args{bypass},

  );

# ---   *   ---   *   ---

  my $frame=$self->{frame};
  my $m=$frame->{master};

  my $lang=$m->{lang};

# ---   *   ---   *   ---
# get size from type, in bytes

  my $elem_sz=$lang->{types}->{$type}->{size};
  my $inc_size=(@$ref/2)*$elem_sz;

# ---   *   ---   *   ---
# 'half' is the register size
#
#   > named such because it's half a unit in
#     our target architechture
#
# 'unit' represents element alignment
#
# that means:
#
#   > *minimum* size of each block entry
#   > entry size is a multiple of unit size


  my $half_sz=$lang->{types}->{half}->{size};
  my $gran=(1<<($elem_sz*8))-1;

  # save top of stack
  my $j=@{$m->{ptr}->{mem}};

  # grow MEM
  my $growth=$m->{ptr}->nunit(
    $attrs->{size}

  );

  $self->{size}+=$growth;

  my @names=();
  my $names_at=$self->{elems_i}->{$j}=[];

# ---   *   ---   *   ---
# push elements to data

  my $i=0;
  while(@$ref) {

    my $ar=shift @$ref;

    # name/value pair
    my $k=$ar->[0];
    my $v=$ar->[1];

    # prohibit redeclaration
    $self->haselem($k,1);

    push @$names_at,$k;

    # clear out free slot mark | trash values
    if(!$i) {
      $m->{ptr}->{mem}->[$j]=0x00;

    };

    # 'i' is offset in bytes
    # mask is derived from element size
    my $shf=$i*8;

# ---   *   ---   *   ---
#  >create ptr instance
#  >save reference to elems

    if(!$bypass) {$v=$self};
    $self->{elems}->{$k}=$m->{ptr}->nit(

      lname=>$k,
      scope=>$self->ances,
      idex=>$j,

      mask=>$gran,
      shf=>$shf,

      type=>$type,
      elem_sz=>$elem_sz,
      blk=>$v,

    );

# ---   *   ---   *   ---
# go to next memory element

    $i+=$elem_sz;
    push @names,$k;

    if(($i>=$half_sz) && @$ref) {

      $j++;$i=0;
      $names_at=$self->{elems_i}->{$j}=[];

# ---   *   ---   *   ---
# warn about over-args

      if(!defined $m->{ptr}->{mem}->[$j]
      && @$ref

      ) {

        arstd::errout(
          'New entry on block <%s> has'.q{ }.
          'a maximum size of %i bytes;'.q{ }.

          'each element is [%i] bytes wide'.q{ }.
          'and [%i] were discarded',

          args=>[

            $self->ances,
            $growth,

            $elem_sz,
            int(@$ref)

          ],

        );

        last;

      };

    };

# ---   *   ---   *   ---

  };

  return ($growth,@names);

};

# ---   *   ---   *   ---
# in: name,value
# sets value at offset

sub setv($self,$name,$value) {
  my $fr_ptr=$self->{frame}->{master}->{ptr};
  $fr_ptr->fetch($name)->setv($value);

  return;

};

# ---   *   ---   *   ---
# in: name to fetch
# returns stored value

sub getv($self,$name) {
  my $fr_ptr=$self->{frame}->{master}->{ptr};
  return $fr_ptr->fetch($name)->getv();

};

# ---   *   ---   *   ---
# in: name to fetch
# returns addr assoc with name

sub getloc($self,$name) {
  my $fr_ptr=$self->{frame}->{master}->{ptr};
  return $fr_ptr->fetch($name)->addr();

};

# ---   *   ---   *   ---
# prints out block

sub prich($self,%opt) {

  # opt defaults
  $opt{errout}//=0;

  my $lang=$self->{frame}->{master}->{lang};
  my $fr_ptr=$self->{frame}->{master}->{ptr};

# ---   *   ---   *   ---
# walk the hierarchy

  my @blocks=($self);
  my @names=();
  my @idexes=();

  while(@blocks) {

    my $self=shift @blocks;

# ---   *   ---   *   ---
# get names ordered by index

    my %h=%{$self->{elems}};
    my @ar=();

    my $long_sz=$lang->{types}->{long}->{size};

    my @order=sort {$a<=>$b}
      keys %{$self->{elems_i}};

    push @idexes,@order;
    push @names,map {

      [$self,@{$self->{elems_i}->{$ARG}}]

    } @order;

    unshift @blocks,@{$self->{children}};

# ---   *   ---   *   ---

  };

  my $prev=undef;
  my $mess=$NULLSTR;

  for my $names(@names) {
    my $mem_idex=shift @idexes;
    my $self=shift @$names;

# ---   *   ---   *   ---

    if(!defined $fr_ptr->{mem}->[$mem_idex]) {
      next;

    };

    if(!defined $prev || $prev!=$self) {
      $mess.="\n<".$self->ances.">\n";

    };

# ---   *   ---   *   ---

    $prev=$self;

    my $line=q{ }x2 .

      "0x%016X".q{ }.
      "%-54s\n"

    ;

# ---   *   ---   *   ---

    my $s=$NULLSTR;

    for my $name(reverse @$names) {

      my $ptr=$self->{elems}->{$name};
      $s.=sprintf "%s(%i) ",
        $ptr->{lname},
        $ptr->bytesz

      ;

    };

    $line=sprintf $line,
      $fr_ptr->{mem}->[$mem_idex],$s;

    $mem_idex++;

# ---   *   ---   *   ---
# show padding if it's there

    my $ahead=$idexes[0];
    if(!defined $ahead) {
      $ahead=@{$fr_ptr->{mem}};

    };

    while($ahead>$mem_idex) {

      $line.=sprintf
        q{ }x2 . "0x%016X\n",

        $fr_ptr->{mem}->[$mem_idex];

      $mem_idex++;

    };

    $mess.=$line;

# ---   *   ---   *   ---
# spit it out

  };

  # select filehandle
  my $FH=($opt{errout})
    ? *STDERR
    : *STDOUT
    ;

  return print {$FH} "$mess\n";

};

# ---   *   ---   *   ---
# mngr class

package peso::blk::frame;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

  use peso::ptr;

# ---   *   ---   *   ---
# constructors

# makes reg

sub new_data_block($frame,$header,$data) {

  my $m=$frame->{master};
  my $name=$data->[0];

  my $dst=($frame->{dst}->{attrs})
  ? $frame->{dst}->{parent}
  : $frame->{dst}
  ;

# ---   *   ---   *   ---
# append new block to dst on first pass

  my $blk;
  if($m->fpass()) {
    $blk=$frame->nit(
      $dst,$name,$O_RD|$O_WR,

    );

# ---   *   ---   *   ---
# second pass: look for block

  } else {
    my $ptr=$name;
    $blk=$ptr->blk;

  };

# ---   *   ---   *   ---
# overwrite dst

  $frame->{dst}=($blk);
  $frame->setscope($blk);
  $frame->setcurr($blk);

  return $blk;

};

# ---   *   ---   *   ---

sub resolve_ptrs($frame) {

  state $peso_st_re=qr{^peso::}x;

  my $lang=$frame->{master}->{lang};
  my $blk=$frame->{non};

  my @ar=();
  my @blocks=($blk);
  while(@blocks) {

    $blk=shift @blocks;

    for my $ptr(values %{$blk->{elems}}) {

      my $idex=$ptr->byteoff();
      $ar[$idex]=$ptr;

    };

    unshift @blocks,@{$blk->{children}};

  };

# ---   *   ---   *   ---

  my @ptrs=();
  while(@ar) {

    my $ptr=shift @ar;
    if(defined $ptr) {
      push @ptrs,$ptr;

    };

  };

# ---   *   ---   *   ---

  for my $ptr(@ptrs) {

    my $v=$ptr->{blk};

    if($v=~ $peso_st_re) {
      $v=$v->as_long();

    } elsif($v=~ $lang->{nums_re}) {
      $lang->numcon(\$v);

    };

    $ptr->setv($v);

  };

};

# ---   *   ---   *   ---
# makes reg entry

sub new_data_ptr($frame,$header,$data) {

  my $m=$frame->{master};

  my $type=$header->{type}->[-1];
  my $spec=$header->{spec}->[-1];

# ---   *   ---   *   ---
# TODO: handle multiple types/specifiers
# but for now this is sufficient

  my $wed=$type;
  if($spec eq 'ptr') {
    $wed='unit';

  };

# ---   *   ---   *   ---
# open new typing mode

  my $old=$m->{ptr}->wed('get');
  $m->{ptr}->wed($wed);

# ---   *   ---   *   ---
# grow block on first pass

  if($m->fpass()) {
    $frame->{dst}->expand($data,type=>$wed);

# ---   *   ---   *   ---
# overwrite on second pass

  } else {

    for my $pair(@$data) {

      my $ptr=$pair->[0];
      my $value=$pair->[1];

# ---   *   ---   *   ---
# mask to size of element at address

      $ptr->mask_to($type);

      # use special signature for nullptr
      if(!$value && $wed eq 'unit') {
        $value=$NULL;

      };

# ---   *   ---   *   ---
# copy address when not dereferencing

      if(peso::ptr::valid($value)) {
        $value=$value->{addr};

      };

      # write value to address
      $ptr->setv($value);

    };
  };

# ---   *   ---   *   ---
# restore typing mode

  $m->{ptr}->wed($old);
  return $frame->{dst};

};

# ---   *   ---   *   ---

sub nit(@args) {return peso::blk::nit(@args)};

sub create($master) {

  my $frame=bless {

    self=>undef,
    non=>undef,
    curr=>undef,

    dst=>undef,

    blocks=>undef,
    ptrstk=>undef,

    master=>$master,

  },'peso::blk::frame';

# ---   *   ---   *   ---

  $frame->{dst}

  =

  $frame->{non}

  =

  $frame->nit(undef,'non',undef)

  ;

# ---   *   ---   *   ---

  $frame->{blocks}=$frame->{non}->{elems};
  $frame->{prstk}=stack::nit(0,[]);

  $frame->setscope($frame->{non});

  return $frame;

};

# ---   *   ---   *   ---
# in: block name
# errchk and get root block

sub clan($frame,$key) {

  my $out=undef;

# ---   *   ---   *   ---
# return local scope

  if($key eq 'self') {
    $out=$frame->{self};

# ---   *   ---   *   ---
# return base block

  } elsif($key eq 'non') {
    $out=$frame->{non};

# ---   *   ---   *   ---
# name lookup

  } elsif(

      $frame->{master}
      ->ptr->is_block_ref($key)

  ) {

    $out

      =$frame->{master}
      ->{ptr}->fetch($key)->{blk}

    ;

# ---   *   ---   *   ---
# throw err

  } else {

    arstd::errout(

      "No root block named '%s'\n",

      args=>[$key],
      lvl=>$FATAL,

    );

  };

  return $out;

};

# ---   *   ---   *   ---
# in: block instance
# scope frame to block

sub setscope($frame,$blk) {

  $frame->{self}=$blk;

  if(!$blk->{scope}) {
    $blk->{scope}=$blk;

  };

# ---   *   ---   *   ---
# add scope names to list

  my @ar=($frame->{self}->ances);
  if(defined $frame->{curr}) {

    my $curr=$frame->{curr};
    push @ar,$curr->ances;

    if(defined $curr->{parent}) {
      push @ar,$curr->{parent}->ances;

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

# ---   *   ---   *   ---

  if(!$hasnon) {push @ar,'non';};
  $frame->{master}->{ptr}->setscope(@ar);

  return;

};

# ---   *   ---   *   ---
# in: frame, block instance
# set current local space

sub setcurr($frame,$blk) {
  $frame->{curr}=$blk;
  return;

};

# ---   *   ---   *   ---
# in:tree,

# block-deref
#   0|undef:common ptr
#   !0:block ptr

# solve operations in tree

sub treesolve($frame,$node,$type) {

  my $master=$frame->{master};
  my $fr_ptr=$master->{ptr};

  my $pesc=$master->{lang}->{pesc};

  # save current cast and override
  my $wed=$fr_ptr->wed('get');
  if($type) {$fr_ptr->wed($type);};

# ---   *   ---   *   ---
# iter tree

  for my $leaf(@{$node->{leaves}},$node) {

    # skip $:escaped;>
    if($leaf->{value}=~ m/${pesc}/) {
      next;

    };

    # solve/fetch non-numeric values
    if(!($leaf->{value}=~ m/^[0-9]+/)) {
      $frame->refsolve_rec($leaf);
      $leaf->collapse();

    };

  };

# ---   *   ---   *   ---
# restore cast and dereference pointers

  $frame->ptrderef_rec($node);
  $node->collapse();

  $fr_ptr->wed($wed);
  return;

};

# ---   *   ---   *   ---
# in: tree
# recursively solve pointer dereferences

sub ptrderef_rec($frame,$node) {

  my $master=$frame->{master};
  my $fr_ptr=$master->{ptr};

# ---   *   ---   *   ---
# value is ptr dereference

  if($node->{value} eq '[') {

    my $leaf=$node->{leaves}->[0];
    my $is_ptr=peso::ptr::valid($leaf->{value});

    if($is_ptr) {
      $node->value($leaf->{value}->getv());

    } else {
      $node->value(
        $fr_ptr->fetch($leaf->{value})->getv()

      );

    };$node->pluck(@{$node->{leaves}});

# ---   *   ---   *   ---
# not a pointer derefernce: go to next level

  } else {

    for my $leaf(@{$node->{leaves}}) {
      $frame->ptrderef_rec($leaf);

    };
  };

  return;

};

# ---   *   ---   *   ---
# recursive name solver

sub refsolve_rec($frame,$node) {

  my $master=$frame->{master};
  my $fr_ptr=$master->{ptr};

  my $is_ptr=$fr_ptr->valid($node->{value});
  my $is_name=$master->{lang}->valid_name(
    $node->{value}

  );

# ---   *   ---   *   ---

  if($is_name || $is_ptr) {

    if($frame->{master}->fpass()) {
      return;

    } elsif($is_ptr) {
      $node->value($node->{value}->{addr});

    };

# ---   *   ---   *   ---

  } else {
    for my $leaf(@{$node->{leaves}}) {
      $frame->refsolve_rec($leaf);

    };

  };

  return;

};

# ---   *   ---   *   ---
1; # ret
