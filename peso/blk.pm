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

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

  use lang;
  use stack;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';

  our @EXPORT=qw(
    O_RD O_WR O_EX
    O_RDWR O_RDEX O_WREX
    O_RDWREX FREEBLOCK

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v2.8;
  our $AUTHOR='IBN-3DILA';

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
# check value is an instance of this class

sub valid($blk) {return arstd::valid($blk)};

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

  my $insid=($attrs& O_EX)
    ? $frame->master->nxins
    : -1
    ;

  my $blk=bless {

    name=>$name,
    size=>0,

    par=>$parent,
    children=>[],
    stack=>stack::nit(stack::slidex(0x100)),
    scope=>$frame->{-SELF},

    elems=>{},
    attrs=>$attrs,
    insid=>$insid,
    frame=>$frame,

    id=>undef,

  },'peso::blk';

# ---   *   ---   *   ---
# initialized from instance

  # new->setParent $self
  if(defined $parent) {
    $parent->elems->{$name}=$blk;

  # is root block
  } else {

# ---   *   ---   *   ---
# redecl guard

    if(exists $frame->{-BLOCKS}->{$name}) {

      arstd::errout(

        'Ilegal operation: '.
        'redeclaration of root block '.
        "'%s' at global scope\n",

        args=>[$name],
        lvl=>FATAL,

      );

    };

# ---   *   ---   *   ---

    $parent=$frame->{-SOIL};

    $blk->{id}=$frame->{-BIDS}->spop();
    #$frame->{-BBID}->[$blk->{id}]=$blk;

# ---   *   ---   *   ---
# only non can be orphaned

  };if($name ne 'non') {
    $parent->addchld($blk);

  };

# ---   *   ---   *   ---
# NOTE: lyeb@IBN-3DILA on 6/27/22 10:46 AM
#
#   this bit is supposed to help out with
#   fetching blocks that contain executable data
#   (along with other INSID/BBID-type attrs)
#
#   we have deprecated the old format for that,
#   but the logic *might* still be useful
#
#   i believe the system should be redesigned,
#   however some pieces of the old one could
#   be needed. i can't say just yet.
#
# ---   *   ---   *   ---

  if($insid>=0) {
    $frame->{-INS_ARR}->[$insid]=$blk;

  };

  return $blk;

};

# ---   *   ---   *   ---
# convenience settings for sub-blocks

sub addchld($self,$blk) {

  my $frame=$self->frame;

  my $i=$self->sstack->spop();
  my $j=$self->{id};

  # add block data into this line
  my @line=(

    [$blk->name,$blk],

  );

# ---   *   ---   *   ---

  my $bypass=int(
    $self->name eq 'non'
  ||!$self->attrs

  );

# ---   *   ---   *   ---

  $self->expand(\@line,'long',$bypass);
  $self->children->[$i]=$blk;
  $blk->{par}=$self;

  $frame->master->ptr->declscope(
    $blk->ances,
    int(@{$frame->master->ptr->MEM()})

  );

  return;

};

# ---   *   ---   *   ---
# getters

sub name($self) {return $self->{name}};
sub elems($self) {return $self->{elems}};
sub par($self) {return $self->{par}};
sub children($self) {return $self->{children}};
sub sstack($self) {return $self->{stack}};

sub scope($self) {return $self->{scope}};

sub size($self) {return $self->{size}};
sub attrs($self) {return $self->{attrs}};

sub insid($self) {return $self->{insid}};
sub frame($self) {return $self->{frame}};

sub ins($self) {

  return

    $self->frame->{-INS_ARR}
    ->[$self->insid]

  ;

};

# ---   *   ---   *   ---
# find ancestors recursively

sub ances($self) {

  my $name=$self->name;

  while($self->par) {
    $name=$self->par->name.q{@}.$name;
    $self=$self->par;

    if(!defined $self) {last;};

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
    lvl=>FATAL,

  );

  return;

};

# ---   *   ---   *   ---

# in: element name, redecl guard
# errcheck for bad fetch

sub haselem($self,$name,$redecl) {

  my $fr_ptr=$self->frame->master->ptr;

# ---   *   ---   *   ---
# solve compound name (module@sub@elem)

  if($name=~ m/@/) {
    my $blk=$fr_ptr->fetch($name)->blk;
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
    if(valid $self->elems->{$name}) {
      goto TAIL;

    };

# ---   *   ---   *   ---
# redecl guard

    arstd::errout(
      'Redeclaration of \'%s\''.
      "at block <%s>\n",

      args=>[$name,$self->ances],
      lvl=>FATAL,

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

sub expand($self,$ref,$type,$bypass) {

  my $frame=$self->frame;
  my $m=$frame->master;

  my $lang=$m->lang;

# ---   *   ---   *   ---
# get size from type, in bytes

  my $elem_sz=$lang->types->{$type}->size;
  my $inc_size=@$ref*$elem_sz;

# ---   *   ---   *   ---
# 'line' is size of two registers
# 'unit' is size of a single register
# we use these as minimum size for blocks

  my $line_sz=$lang->types->{'line'}->size;
  my $gran=(1<<($elem_sz*8))-1;

# ---   *   ---   *   ---
# grow block on first pass

  my $j=0;if($m->fpass()) {

    # save top of stack
    $j=@{$m->ptr->MEM()};
    $self->{-SIZE}+=$inc_size;

    # reserve new unit
    $m->ptr->nunit();

  };

# ---   *   ---   *   ---
# push elements to data

  my $i=0;for my $ar(@$ref) {

    # name/value pair
    my $k=$ar->[0];
    my $v=$ar->[1];

    # prohibit redeclaration
    if($m->fpass()) {
      $self->haselem($k,1);

    };

    # 'i' is offset in bytes
    # mask is derived from element size
    my $shf=$i*8;

# ---   *   ---   *   ---
# first pass || root block decl:
#  >create ptr instance
#  >save reference to elems

    if($m->fpass() || $bypass) {

      if(!$bypass) {$v=$self;};
      $self->elems->{$k}=$m->ptr->nit(

        lname=>$k,
        scope=>$self->ances,
        idex=>$j,

        mask=>$gran,
        shf=>$shf,

        type=>$type,
        elem_sz=>$elem_sz,
        blk=>$v

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
      if($m->fpass()) {
        $m->ptr->nunit();

      };$j++;$i=0;

    };

# ---   *   ---   *   ---

  };

  return;

};

# ---   *   ---   *   ---
# in: name,value
# sets value at offset

sub setv($self,$name,$value) {
  my $fr_ptr=$self->frame->master->ptr;
  $fr_ptr->fetch($name)->setv($value);

  return;

};

# ---   *   ---   *   ---
# in: name to fetch
# returns stored value

sub getv($self,$name) {
  my $fr_ptr=$self->frame->master->ptr;
  return $fr_ptr->fetch($name)->getv();

};

# ---   *   ---   *   ---
# in: name to fetch
# returns addr assoc with name

sub getloc($self,$name) {
  my $fr_ptr=$self->frame->master->ptr;
  return $fr_ptr->fetch($name)->addr();

};

# ---   *   ---   *   ---
# prints out block

sub prich($self,%opt) {

  # opt defaults
  $opt{errout}//=0;

  my $fr_ptr=$self->frame->master->ptr;
  my $mess=NULLSTR;

# ---   *   ---   *   ---
# select filehandle

  my $FH=($opt{errout})
    ? *STDERR
    : *STDOUT
    ;

# ---   *   ---   *   ---

  my @blocks=($self);
  while(@blocks) {

    my $self=shift @blocks;

    my $v_lines=NULLSTR;
    my @data=();

    $mess.='<'.$self->ances.">\n";
    my $wed=$fr_ptr->wed('get');
    $fr_ptr->wed(undef);

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
    my $unit_names=NULLSTR;

    # iter list
    while(@data) {

      my $ref=shift @data;
      my ($name,$i,$shf,$sz)=@{$ref};

# ---   *   ---   *   ---
# unit switch

      if(defined $last_idex) {
        if($last_idex!=$i) {
          $v_lines.=sprintf
            "  0x%.16X %.32s\n",
            $unit,$unit_names;

          $unit=0x00;
          $unit_names=NULLSTR;

        };

# ---   *   ---   *   ---
# accumulate

      };$last_idex=$i;
      $unit=$fr_ptr->MEM->[$i];
      $unit_names="$name($sz) ".$unit_names;

    };

# ---   *   ---   *   ---
# append leftovers

    $v_lines.=sprintf
      "  0x%.16X %.32s\n",
      $unit,$unit_names;

    $mess.=$v_lines."\n";

    $fr_ptr->wed($wed);
    unshift @blocks,@{$self->children};

  };

# ---   *   ---   *   ---
# spit it out

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
# getters/setters

sub entry($frame,$new=undef) {

  if(defined $new) {
    $frame->{-ENTRY}=$new;

  };return $frame->{-ENTRY};

};sub nxins($frame,$new=undef) {

  if(defined $new) {
    $frame->{-NXINS}=$new;

  };return $frame->{-NXINS};

};

# ---   *   ---   *   ---

sub INS($self) {return $self->{-INS_ARR}};

sub incpass($self) {return $self->{-PASS}++};
sub fpass($self) {return !($self->{-PASS})};
sub master($self) {return $self->{-MASTER}};

# ---   *   ---   *   ---
# adjusts current write-to

sub DST($frame,$new=undef) {

  if(defined $new) {
    $frame->{-DST}=$new;

  };return $frame->{-DST};

};sub NON($self) {return $self->{-SOIL}};

# ---   *   ---   *   ---
# constructors

# makes reg

sub new_data_block($frame,$header,$data) {

  my $m=$frame->master;
  my $name=$data->[0];

  my $dst=($frame->DST->attrs)
  ? $frame->DST->par
  : $frame->DST
  ;

# ---   *   ---   *   ---
# append new block to dst on first pass

  my $blk;
  if($m->fpass()) {
    $blk=$frame->nit(
      $dst,$name,peso::blk->O_RDWR,

    );

# ---   *   ---   *   ---
# second pass: look for block

  } else {
    my $ptr=$name;
    $blk=$ptr->blk;

  };

# ---   *   ---   *   ---
# overwrite dst

  $frame->DST($blk);
  $frame->setscope($blk);
  $frame->setcurr($blk);

  return $blk;

};

# ---   *   ---   *   ---
# makes reg entry

sub new_data_ptr($frame,$header,$data) {

  my $m=$frame->master;

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

  my $old=$m->ptr->wed('get');
  $m->ptr->wed($wed);

# ---   *   ---   *   ---
# grow block on first pass

  if($m->fpass()) {
    $frame->DST->expand($data,$wed,0);

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
        $value=NULL;

      };

# ---   *   ---   *   ---
# copy address when not dereferencing

      if(peso::ptr::valid $value) {
        $value=$value->addr;

      };

      # write value to address
      $ptr->setv($value);

    };
  };

# ---   *   ---   *   ---
# restore typing mode

  $m->ptr->wed($old);
  return $frame->DST;

};

# ---   *   ---   *   ---

sub nit(@args) {return peso::blk::nit(@args)};

sub create($master) {

  my $frame=bless {

    -SELF=>undef,
    -SOIL=>undef,
    -CURR=>undef,

    -DST=>undef,

    -BLOCKS=>undef,
    -BBID=>[0..0xFF],
    -BIDS=>stack::nit(stack::slidex(0x100)),

    -NXINS=>0,
    -INS_ARR=>[],

    -ENTRY=>'nit',

    -PASS=>0,
    -PRSTK=>undef,

    -MASTER=>$master,

  },'peso::blk::frame';

  $frame->{-SOIL}=$frame->nit(
    undef,'non',undef

  );$frame->DST($frame->{-SOIL});

  $frame->{-BLOCKS}=$frame->{-SOIL}->{-ELEMS};
  $frame->{-PRSTK}=stack::nit(0,[]);

  $frame->setscope($frame->{-SOIL});

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
    $out=$frame->{-SELF};

# ---   *   ---   *   ---
# return base block

  } elsif($key eq 'non') {
    $out=$frame->{-SOIL};

# ---   *   ---   *   ---
# name lookup

  } elsif(

      $frame->master
      ->ptr->is_block_ref($key)

  ) {

    $out

      =$frame->master
      ->ptr->fetch($key)->blk

    ;

# ---   *   ---   *   ---
# throw err

  } else {

    arstd::errout(

      "No root block named '%s'\n",

      args=>[$key],
      lvl=>FATAL,

    );

  };

  return $out;

};

# ---   *   ---   *   ---
# in: block instance
# scope frame to block

sub setscope($frame,$blk) {

  $frame->{-SELF}=$blk;

  if(!$blk->{scope}) {
    $blk->{scope}=$blk;

  };

# ---   *   ---   *   ---
# add scope names to list

  my @ar=($frame->{-SELF}->ances);
  if(defined $frame->{-CURR}) {

    my $curr=$frame->{-CURR};
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

# ---   *   ---   *   ---

  if(!$hasnon) {push @ar,'non';};
  $frame->master->ptr->setscope(@ar);

  return;

};

# ---   *   ---   *   ---
# in: frame, block instance
# set current local space

sub setcurr($frame,$blk) {
  $frame->{-CURR}=$blk;
  return;

};

# ---   *   ---   *   ---
# program stack methods

sub prstk($frame) {return $frame->{-PRSTK}};

;;sub spush($frame,$v) {
  $frame->prstk->spush($v);
  return;

};sub spop($frame) {return $frame->prstk->spop};

# ---   *   ---   *   ---
# in:tree,

# block-deref
#   0|undef:common ptr
#   !0:block ptr

# solve operations in tree

sub treesolve($frame,$node,$type) {

  my $master=$frame->master;
  my $fr_ptr=$master->ptr;

  my $pesc=$master->lang->pesc;

  # save current cast and override
  my $wed=$fr_ptr->wed('get');
  if($type) {$fr_ptr->wed($type);};

# ---   *   ---   *   ---
# iter tree

  for my $leaf(@{$node->leaves},$node) {

    # skip $:escaped;>
    if($leaf->value=~ m/${pesc}/) {
      next;

    };

    # solve/fetch non-numeric values
    if(!($leaf->value=~ m/^[0-9]+/)) {
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

  my $master=$frame->master;
  my $fr_ptr=$master->ptr;

# ---   *   ---   *   ---
# value is ptr dereference

  if($node->value eq '[') {

    my $leaf=$node->leaves->[0];
    my $is_ptr=$fr_ptr->valid($leaf->value);

    if($is_ptr) {
      $node->value($leaf->value->getv());

    } else {
      $node->value(
        $fr_ptr->fetch($leaf->value)->getv()

      );

    };$node->pluck(@{$node->leaves});

# ---   *   ---   *   ---
# not a pointer derefernce: go to next level

  } else {

    for my $leaf(@{$node->leaves}) {
      $frame->ptrderef_rec($leaf);

    };
  };

  return;

};

# ---   *   ---   *   ---
# recursive name solver

sub refsolve_rec($frame,$node) {

  my $master=$frame->master;
  my $fr_ptr=$master->ptr;

  my $is_ptr=$fr_ptr->valid($node->value);
  my $is_name=$master->lang->valid_name(
    $node->value

  );

# ---   *   ---   *   ---

  if($is_name || $is_ptr) {

    if($frame->fpass()) {
      return;

    } elsif($is_ptr) {
      $node->value($node->value->addr);

    };

# ---   *   ---   *   ---

  } else {
    for my $leaf(@{$node->leaves}) {
      $frame->refsolve_rec($leaf);

    };

  };

  return;

};

# ---   *   ---   *   ---
1; # ret
