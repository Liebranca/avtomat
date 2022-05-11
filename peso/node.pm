#!/usr/bin/perl
# ---   *   ---   *   ---
# NODE
# Makes peso trees
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::node;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/include/';
  use lib $ENV{'ARPATH'}.'/lib/';

  use peso::decls;
  use peso::defs;
  use peso::ptr;

# ---   *   ---   *   ---

my %CACHE=(

  -TREES=>[],

  -DEPTH=>[],
  -LDEPTH=>0,
  -ANCHOR=>undef,

  -BLOCKS=>undef,
  -NUMCOM=>undef,

);

# ---   *   ---   *   ---

# load notation-to-decimal procs
sub loadnumcon {$CACHE{-NUMCON}=shift;};

# ---   *   ---   *   ---

# in: self,val
# make child node or create a new tree
sub nit {

  # pass undef for new tree
  my $self=shift;

  # value for new node
  my $val=shift;

  # tree/root handle
  my %tree=(

    -FUSE=>undef,
    -ROOT=>undef,

  );my $tree_id;

# ---   *   ---   *   ---

  # make new tree if !$self
  if(!(defined $self)) {

    my @ar=@{ $CACHE{-TREES} };
    $tree_id=@ar;

    if(defined $CACHE{-ANCHOR}) {

      $tree{-FUSE}=$CACHE{-DEPTH}->[-1];
      $tree{-ROOT}=undef;

    };

    push @{ $CACHE{-TREES} },\%tree;

# ---   *   ---   *   ---

  # ... or fetch from id
  } else {
    $tree_id=$self->{-ROOT};
    %tree=%{ $CACHE{-TREES}->[$tree_id] };

  # make node instance
  };my $node=bless {

    -VAL=>$val,
    -LEAVES=>[],

    -ROOT=>$tree_id,
    -PAR=>undef,
    -INDEX=>0,

  },'peso::node';

# ---   *   ---   *   ---

  # add leaf if $self
  if(defined $self) {

    $node->{-INDEX}=$self->idextrav();

    push @{ $self->leaves },$node;
    $node->{-PAR}=$self;

  } else {
    $tree{-ROOT}=$node;

  };return $node;

};

# ---   *   ---   *   ---

# getters

sub leaves {return (shift)->{-LEAVES};};
sub par {return (shift)->{-PAR};};
sub val {return (shift)->{-VAL};};

# ---   *   ---   *   ---

sub mksep {

  return bless {

    -VAL=>'$:cut;>',
    -LEAVES=>[],

    -ROOT=>0,
    -PAR=>undef,

  },'node';

};

sub dup {

  my $self=shift;
  my $root=shift;

  my @leaves=();

  my $copy=nit($root,$self->val);

  for my $leaf(@{$self->leaves}) {
    $leaf->dup($copy);

  };

  return $copy;

};

# ---   *   ---   *   ---

sub branch_reloc {

  my $self=shift;

  # get branch reallocation
  my $tree_id=$self->{-ROOT};
  my %tree=%{ $CACHE{-TREES}->[$tree_id] };

  # move branches to saved tree node
  if($tree{-FUSE}) {
    $tree{-FUSE}->pushlv(0,$self);

  };
};

# ---   *   ---   *   ---

sub group {

  my $self=shift;
  my $idex=shift;
  my $sub=shift;

  # errchk
  if(!@{$self->leaves}) {

    printf

      "Node <".$self->val.
      "> has no children\n";

    exit;

  };

# ---   *   ---   *   ---
# get nth group

  my $group=$self->leaves->[$idex];

  # get nth element in group
  if(defined $sub) {

    my $node=$group->leaves->[$sub];
    return $node;

  };return $group;

};

# ---   *   ---   *   ---

# {} open/close

sub ocurl {
  my $self=shift;
  my $val=shift;

  # use self as fake root
  push @{ $CACHE{-DEPTH} },$self;
  $CACHE{-LDEPTH}++;

  # new nodes append to
  $CACHE{-ANCHOR}=$self;

};sub ccurl {
  my $self=shift;
  my $val=shift;

  # remove last fake root
  my $node=pop @{ $CACHE{-DEPTH} };
  $CACHE{-LDEPTH}--;

  # unset dead anchors
  if(!$CACHE{-LDEPTH}) {
    $CACHE{-ANCHOR}=undef;

  };

  # reorder branches
  $node->pluck($self);
  my @leaves=$self->pluck(@{ $self->leaves });
  push @leaves,$self;

  $node->pushlv(0,@leaves);

};

# ---   *   ---   *   ---

# () open/close

sub oparn {
  my $self=shift;
  my $val=shift;

  if($val) {
    $self->nit($val);

  };

  my $node=$self->nit('(');

  return $node;

}; sub cparn {
  my $self=shift;
  my $val=shift;

  if($val) {$self->nit($val);};
  my $node=$self->nit(')');

  return $node;

};

# ---   *   ---   *   ---

# [] open/close

sub obrak {
  my $self=shift;
  my $val=shift;

  if($val) {
    $self->nit($val);

  };

  my $node=$self->nit('[');

  return $node;

}; sub cbrak {
  my $self=shift;
  my $val=shift;

  if($val) {$self->nit($val);};
  my $node=$self->nit(']');

  return $node;

};

# ---   *   ---   *   ---

sub walkup {

  my $self=shift;
  my $top=shift;

  if(!defined $top) {
    $top=-1;

  };

  my $node=$self->par;
  my $i=0;

  while($top<$i) {
    my $par=$node->par;
    if($par) {
      $node=$par;

    } else {last;};$i++;
  };

  return $node;

};

# ---   *   ---   *   ---

sub shiftlv {

  my $self=shift;
  my $pos=shift;
  my $sz=shift;

  for my $i(0..$sz-1) {
    $self->nit('BLANK');

  };

  my $end=@{$self->leaves}-1;
  for my $i(reverse ($pos..$end)) {

    $self->leaves->[$i]
      =$self->leaves->[$i-1];

  };$self->idextrav();

};

# ---   *   ---   *   ---

# in:overwrite,node arr
# push node array to leaves
sub pushlv {

  my $self=shift;

  my $overwrite=shift;
  if($overwrite) {
    $self->{-LEAVES}=[];

  };

# ---   *   ---   *   ---

  # move nodes
  my %cl=();
  while(@_) {

    my $node=shift;
    if($node eq '$:cut;>') {
      $node=node::mksep();

    };

    my $par=$node->par;

    $node->{-ROOT}=$self->{-ROOT};
    $node->{-PAR}=$self;

    push @{ $self->leaves },$node;

    if($par && $par!=$node->par) {
      $par->pluck($node);
      $cl{$par}=$par;

    };

  };for my $node(keys %cl) {
    $node=$cl{$node};
    $node->cllv();

  };
};

# ---   *   ---   *   ---

# discard blank nodes
sub cllv {

  my $self=shift;
  my @cpy=();

  for(

    my $i=0;

    $i<@{ $self->leaves };
    $i++

  ) {

    # push only nodes that arent plucked
    my $node=$self->leaves->[$i];
    if(defined $node) {
      push @cpy,$node;

    };

  # overwrite with filtered array
  };$self->{-LEAVES}=[@cpy];

};

# ---   *   ---   *   ---

# in:self,string
# branch out node from whitespace split

sub tokenize {

  # instance
  my $self=shift;

  # data
  my $exp=shift;

  my $exp_depth_a=0;
  my $exp_depth_b=0;

  my @anch=($self);

  # patterns
  my $ops=peso::decls::ops;
  my $del_op=peso::decls::del_ops;
  my $ndel_op=peso::decls::ndel_ops;

  my $ode=peso::decls::ode;
  my $cde=peso::decls::cde;
  my $pesc=peso::decls::pesc;

# ---   *   ---   *   ---
# spaces are meaningless

  my @elems=();
  my @ar=split m/([^\s]*)\s+/,$exp;

  while(@ar) {
    my $elem=shift @ar;

    if(defined $elem && length $elem) {
      $self->nit($elem);

    };
  };

# ---   *   ---   *   ---

};

# ---   *   ---   *   ---
# clump fields of arguments together

sub agroup {

  my $self=shift;

  my @shifts=();
  my $i=0;

# ---   *   ---   *   ---
# break at commas

  for my $leaf(@{$self->leaves}) {

    if($leaf->val=~ m/,/) {

      my @values=split ',',$leaf->val;

      if(0<index $leaf->val,',') {
        $leaf->{-VAL}='$:group;>';
        push @shifts,[$leaf,\@values,$i+1]

      };

    };$i++;

# ---   *   ---   *   ---
# populate fields

  };for my $ref(@shifts) {

    my $anchor=$ref->[0];
    my @values=@{$ref->[1]};
    my $pos=$ref->[2];
    my $sz=@values;

    for $i(0..$sz-1) {
      $anchor->nit(shift @values);

    };

  };

# ---   *   ---   *   ---
# break at delimiters

  my $ode=peso::decls::ode;
  my $cde=peso::decls::cde;

  for my $leaf(@{$self->leaves}) {

    $i=0;
    for my $grch(@{$leaf->leaves}) {

      $grch->{-VAL}=~ s/(${ode}|${cde})/ $1 /sg;
      my @values=split ' ',$grch->val;

      if(!defined $values[0]) {shift @values;};

# ---   *   ---   *   ---

      if(@values>1) {

        $grch->{-VAL}='$:group;>';
        for my $value(@values) {
          $grch->nit($value);

        };$grch->delimbrk();

# ---   *   ---   *   ---

        $grch->subdiv();

        my $top=$grch->leaves->[0];

        $grch->pluck($grch->leaves->[0]);
        $leaf->leaves->[$i]=$top;

# ---   *   ---   *   ---

      } else {
        $grch->subdiv();

      };$i++;
    };
  };

# ---   *   ---   *   ---
# break at delimiters

};sub delimbrk {

  my $self=shift;

  my @anchors=();
  my @moved=();

  my $ode=peso::decls::ode;
  my $cde=peso::decls::cde;

  for my $leaf(@{$self->leaves}) {

    if($anchors[-1]) {
      push @{$moved[-1]},$leaf;

    };

# ---   *   ---   *   ---

    if($leaf->val=~ m/${ode}/) {
      push @anchors,$leaf;
      push @moved,[];

    } elsif($leaf->val=~ m/${cde}/) {
      my $anchor=pop @anchors;
      my $ref=pop @moved;

      $self->pluck(@$ref);
      $anchor->pushlv(0,@$ref);

    };

  };

# ---   *   ---   *   ---

};sub reorder {

  my $self=shift;

  my $i=0;while($i<@{$self->leaves}) {
    peso::symbol::ndconsume($self,\$i);

  };

};sub exwalk {

  my $self=shift;
  my @leaves=($self);

TOP:

  $self=shift @leaves;

  if(peso::symbol::valid($self->val)) {
    $self->{-VAL}=$self->val->code->($self);
    $self->pluck(@{$self->leaves});

  } else {
    push @leaves,@{$self->leaves};

  };if(@leaves) {goto TOP;};

};

# ---   *   ---   *   ---

# in: node to replace self by
# replaces a node in the hierarchy

sub repl {

  my $self=shift;
  my $other=shift;

  my $ref=$self->par->leaves;
  my $i=-1;

  for my $node(@$ref) {

    $i++;if($node eq $self) {
      last;

    };
  };

  if($i>=0) {
    $ref->[$i]=$other;

  };

};

# ---   *   ---   *   ---

# in: node list
# removes leaves from node
sub pluck {

  # instance
  my $self=shift;

  # data
  my @ar=@_;

  # return value
  my @plucked=();

# ---   *   ---   *   ---

  # match nodes in list
  { my $i=0;for my $leaf(
    @{ $self->leaves }

  # skip removed nodes
  ) { if(!$leaf) {next;};

      # iter node array
      my $j=0;for my $node(@ar) {

        # skip already removed ones
        if(!$node) {$j++;next;};

# ---   *   ---   *   ---

        # node is in remove list
        if($leaf eq $node) {

          # save the removed nodes
          push @plucked,$self->leaves->[$i];

          # remove from list and leaves
          $ar[$j]=undef;
          $self->leaves->[$i]=undef;

          # go to next leaf
          last;

        };$j++; # next in remove list
      };$i++; # next in leaves
    };
  };

# ---   *   ---   *   ---

  # discard blanks
  $self->cllv();

  # return removed nodes
  return @plucked;

};

# ---   *   ---   *   ---

sub idextrav {

  my $self=shift;
  my $i=0;

  for my $child(@{$self->leaves}) {
    $child->{-INDEX}=$i;$i++;

  };return $i;

};

# ---   *   ---   *   ---

# breaks expressions down recursively
sub subdiv {

  my $self=shift;
  my $leaf=$self;
  my $root=$self;

  my @leafstack=();
  my @rootstack=();

  my @nodes=();
  my $ndel_op=peso::decls::ndel_ops;
  my $pesc=peso::decls::pesc;

  # operator data
  my $h=peso::decls::op_prec;

# ---   *   ---   *   ---

TOP:{

  $self=$leaf;
  $self->idextrav();

  if(!$self->val) {
    goto SKIP;

  } elsif($self->val=~ m/${pesc}/) {
    goto SKIP;

  };

  # non delimiter operator match
  my @ar=split m/(${ndel_op}+)/,$self->val;

  # we filter out
  my @ops=();
  my @elems=();

# ---   *   ---   *   ---

  # save operators and values separately
  while(@ar) {

    my $e=shift @ar;

    if($e=~ m/(${ndel_op}+)/) {
      push @ops,$e;

    } else {
      push @elems,$e;

    };

  };

  if(!@ops) {goto SKIP;};

# ---   *   ---   *   ---

  my @q=@ops;
  my $popped=0;

REPEAT:{

  # sort ops by priority
  my $highest=9999;
  my $hname=undef;
  my $hidex=0;

  my $i=0;

  for my $op(@q) {

    # skip if already matched
    if(!length $op) {
      $popped++;
      $i++;next;

    };

    # get op priority
    my $j=$h->{$op}->[0];

    # compare to previous
    if($j < $highest) {
      $highest=$j;
      $hname=$op;
      $hidex=$i;

    };$i++;

  };

# ---   *   ---   *   ---

  if(!defined $hname) {
    goto RELOC;

  };

  $q[$hidex]='';

  if(!length $elems[$hidex]) {
    $elems[$hidex]=$self->par->leaves
    ->[$self->{-INDEX}-1];

  };if(!length $elems[$hidex+1]) {
    $elems[$hidex+1]=$self->par->leaves
    ->[$self->{-INDEX}+1];

  };

  my $lhand=$elems[$hidex];
  my $rhand=$elems[$hidex+1];

  my $node=$self->par->nit($hname);

# ---   *   ---   *   ---

  my @operands=();

  # use single operand
  if($h->{$hname}->[1]<2) {

    my $op_n=0;

    if(!defined $rhand) {
      push @operands,$lhand;

    } else {
      push @operands,$rhand;
      $op_n=1;

    };

    # overwrite used operand
    $elems[$hidex+$op_n]=$node;

  # use both
  } else {

    push @operands,($lhand,$rhand);

    $elems[$hidex]=$node;
    $elems[$hidex+1]=$node;

  };

# ---   *   ---   *   ---

  # handle operands
  my @mov=();
  for my $op_elem(@operands) {

    # element is a node
    if((index $op_elem,'peso::node=HASH')>=0) {

      # operand is at root level
      if($op_elem->par eq $node->par) {
        push @mov,$op_elem;

      # ^ or further down the chain
      } else {
        push @mov,$op_elem->par;

      };

    # element is a string
    } else {
      push @mov,nit(undef,$op_elem);

    };

# ---   *   ---   *   ---

  # copy operands into node
  };if(@mov) {
    $node->pushlv(0,@mov);

  };

  # loop back
  push @nodes,$node;
  $i=0;if($popped<@q) {goto REPEAT;};

RELOC:

  $self->par->pluck($nodes[-1]);
  $self->repl($nodes[-1]);

# ---   *   ---   *   ---

};SKIP:{

  $self->idextrav();
  if(!@leafstack && !@{ $self->leaves }) {
    return;

  };

  push @leafstack,@{ $self->leaves };
  $leaf=pop @leafstack;

  @nodes=();
  goto TOP;

}}};

# ---   *   ---   *   ---

# in: value conversion table
# solve expressions in tree

sub collapse {

  my $self=shift;
  my @nums=@{$CACHE{-NUMCON}};

  my $leaf=$self;

  my $ndel_ops=peso::decls::ndel_ops;
  my $del_ops=peso::decls::del_ops;
  my $pesc=peso::decls::pesc;
  my $pesonames=peso::decls::names;

  my @leafstack;

  my $h=peso::decls::op_prec;
  my @solve=();

# ---   *   ---   *   ---

TOP:{

  $self=$leaf;
  if(!length $self->val) {goto SKIP;};
  if($self->val=~ m/${pesc}/) {
    goto SKIP;

  };

  # is operation
  if($self->val=~ m/(${ndel_ops}+)/) {

    my $op=$1;
    my $proc=$h->{$op}->[2];
    my $argval=$self->leaves;

    push @solve,($self,$proc,$argval);

# ---   *   ---   *   ---

  # is value
  } else {

    for my $ref(@nums) {

      my $pat=$ref->[0];
      my $proc=$ref->[1];

      if($self->val=~ m/${pat}/) {
        $self->{-VAL}=$proc->($self->val);
        last;

      } elsif($self->val=~
          m/${pesonames}*/

      ) {last;};

    };
  };

};

# ---   *   ---   *   ---

SKIP:{
  if(!@leafstack && !@{ $self->leaves }) {

    while(@solve) {

      my $args=pop @solve;
      my $proc=pop @solve;
      my $node=pop @solve;

# ---   *   ---   *   ---

      my @argval=();
      for my $v(@{$args}) {

        if($v->val=~ m/${del_ops}/) {

          if($v->val=~ m/\[/) {goto NEXT_OP;};
          push @argval,$v->leaves->[0]->val;

        } elsif(

          $v->val=~ m/${pesonames}*/
        && $proc!=$h->{'->'}->[2]

        ) {

          # names are pointers
          # we don't handle them *here*

          goto NEXT_OP;

        } else {

          # operand reordering
          # done for self->sub->attr chains
          if(

             $proc==$h->{'->'}->[2]
          && $v->val=~ m/@/

          ) {

# wtf?! no need to reorder?????
#            my $old=pop @argval;
            push @argval,($v->val);
#            push @argval,$old;

          # common operand
          } else {push @argval,($v->val);}

        };

      };

# ---   *   ---   *   ---

      for my $arg(@{$args}) {
        if($arg->val eq '[') {goto NEXT_OP;};
        for my $sleaf(@{$arg->leaves}) {
          if($sleaf->val eq '[') {goto NEXT_OP;};

        };

      };

      if(!defined $proc) {

      goto NEXT_OP;

      };

      my $result=$proc->(@argval);
      $node->{-VAL}=$result;
      $node->pluck(@{$args});

      NEXT_OP:

    };return;

  };

# ---   *   ---   *   ---

  push @leafstack,@{ $self->leaves };
  $leaf=pop @leafstack;

  goto TOP;

}};

# ---   *   ---   *   ---
# fetches names from ext module
# replaces these names with ptr references

sub findptrs {

  my $self=shift;

  my $pesc=peso::decls::pesc;
  my $pesonames=peso::decls::names;
  my $types=peso::decls::types_re;

# ---   *   ---   *   ---
# iter leaves

  for my $leaf(@{$self->leaves}) {

    $leaf->findptrs();

    # skip $:escaped;>
    if($leaf->val=~ m/${pesc}/) {
      next;

    };

    # solve/fetch non-numeric values
    if($leaf->val=~ m/${pesonames}*/
    && !($leaf->val=~ m/${types}/)) {
      $leaf->{-VAL}=peso::ptr::fetch($leaf->val);

    };
  };

};

# ---   *   ---   *   ---

# print node leaves
sub prich {

  # instance
  my $self=shift;
  my $depth=shift;

# ---   *   ---   *   ---

  # print head
  if(!defined $depth) {
    printf $self->val."\n";
    $depth=0;

  };

  # iter children
  for my $node(@{ $self->leaves }) {

    printf ''.(
      '.  'x($depth).'\-->'.
#      '['.$node->{-INDEX}.']: '.
      $node->val


    )."\n";$node->prich($depth+1);

  };

# ---   *   ---   *   ---

  if(@{ $self->leaves }) {
    printf '.  'x($depth)."\n";

  };

};

# ---   *   ---   *   ---

