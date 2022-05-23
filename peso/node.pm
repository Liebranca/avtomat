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

  use lang;

  use peso::decls;
  use peso::defs;
  use peso::ptr;

  use Scalar::Util qw/blessed/;

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

sub valid {

  my $node=shift;if(

     blessed($node)
  && $node->isa('peso::node')

  ) {

    return 1;
  };return 0;

};

# ---   *   ---   *   ---

# in: self,val
# make child node or create a new tree
sub nit($$;$) {

  # pass undef for new tree
  my $self=shift;

  # value for new node
  my $val=shift;

  # (optional) key into langdefs dict
  my $langkey=shift;
  if(!defined $langkey) {$langkey=-PESO;};

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

    $langkey=$tree{-ROOT}->{-LANGKEY};

  # make node instance
  };my $node=bless {

    -VALUE=>$val,
    -LEAVES=>[],

    -ROOT=>$tree_id,
    -PAR=>undef,
    -INDEX=>0,

    -LANGKEY=>$langkey,

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

sub langkey {
  my $self=shift;

  my $tree_id=$self->{-ROOT};
  my %tree=%{ $CACHE{-TREES}->[$tree_id] };

  return $tree{-ROOT}->{-LANGKEY};

};

# ---   *   ---   *   ---

sub leaves {return (shift)->{-LEAVES};};
sub par {return (shift)->{-PAR};};

sub value($;$) {

  my $self=shift;
  my $x=shift;

  if(defined $x) {
    $self->{-VALUE}=$x;

  };return $self->{-VALUE};

};

# ---   *   ---   *   ---

sub mksep {

  return bless {

    -VALUE=>'$:cut;>',
    -LEAVES=>[],

    -ROOT=>0,
    -PAR=>undef,

  },'node';

};

# ---   *   ---   *   ---
# makes copy of instance

sub dup {

  my $self=shift;
  my $root=shift;

  my @leaves=();

  my $copy=nit($root,$self->valueue);

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

      "Node <".$self->value.
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
  };$self->pushlv(1,@cpy);

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
  my $ops=lang::all_ops($self->langkey);
  my $del_op=lang::del_ops($self->langkey);
  my $ndel_op=lang::ndel_ops($self->langkey);

  my $ode=lang::ode($self->langkey);
  my $cde=lang::cde($self->langkey);
  my $pesc=lang::pesc($self->langkey);

# ---   *   ---   *   ---
# spaces are meaningless

  my @elems=();

  $exp=~ s/(${del_op})/ $1 /sg;
  $exp=~ s/(${ndel_op}+)/ $1 /sg;
  #$exp=~ s/(,)/ $1 /sg;

  my @ar=split m/([^\s]*)\s+/,$exp;

  while(@ar) {
    my $elem=shift @ar;

    if(defined $elem && length $elem) {
      $self->nit($elem);

    };
  };
};

# ---   *   ---   *   ---
# clump fields of arguments together

sub agroup {

  my $self=shift;

  my @shifts=();
  my $i=0;

## ---   *   ---   *   ---
## break at commas
#
#  for my $leaf(@{$self->leaves}) {
#
#    if($leaf->value=~ m/,/) {
#
#      my @values=split ',',$leaf->value;
#
#      if(0<index $leaf->value,',') {
#        $leaf->value('$:group;>');
#        push @shifts,[$leaf,\@values,$i+1]
#
#      };
#
#    };$i++;
#
## ---   *   ---   *   ---
## populate fields
#
#  };for my $ref(@shifts) {
#
#    my $anchor=$ref->[0];
#    my @values=@{$ref->[1]};
#    my $pos=$ref->[2];
#    my $sz=@values;
#
#    for $i(0..$sz-1) {
#      $anchor->nit(shift @values);
#
#    };
#
#  };
#
## ---   *   ---   *   ---
#
#  for my $leaf(@{$self->leaves}) {
#
#    if(
#
#       $leaf->value ne '$:group;>'
#    && !exists peso::defs::SYMS->{$leaf->value}
#
#    ) {
#
#      my $value=$leaf->value;
#
#      $leaf->value('$:group;>');
#      $leaf->nit($value);
#
#    };
#
#  };

# ---   *   ---   *   ---

  my $h={

    'int'=>1,
    'char*'=>1,

  };

  my $keyword='char';

  my @anchors=();
  my @trash=();

  my @leaves=@{$self->leaves};
  TOP:my $leaf=shift @leaves;

  # INSERT LANG RULES HERE

  if($leaf->value=~ m/^${keyword}/) {
    $leaf->{-VALUE}=~ s/\s*\*/ ptr/sg;

  } elsif($leaf->value=~ m/${keyword}/) {
    $leaf->{-VALUE}=~ s/\*\s*/ptr /sg;

  };

  if($leaf->value eq ',') {
    push @trash,$leaf;
    pop @anchors;

  };

  if($anchors[-1]) {

    my $anchor=$anchors[-1]->[0];
    my $argc=\$anchors[-1]->[1];

    $anchor->nit($leaf->value);
    push @trash,$leaf;

    $$argc--;

    if(!$$argc) {
      pop @anchors;

    };

  };

  if(exists $h->{$leaf->value}) {
    push @anchors,[$leaf,$h->{$leaf->value}];

  };

  unshift @leaves,@{$leaf->leaves};

  if(@leaves) {goto TOP;};
  END:$self->pluck(@trash);

  $self->delimchk();

# ---   *   ---   *   ---
# expands the tree to solve expressions

};sub subdiv2 {

  my $self=shift;

  my $ndel_op=lang::ndel_ops($self->langkey);
  my $del_op=lang::del_ops($self->langkey);

  my %matched=();

  my $root=$self;
  my @leaves=();

  # test hash
  my %h=(

    '++'=>[

      [0,sub {my $x=shift;return ++$$x;}],
      [0,sub {my $x=shift;return $$x++;}],

      undef,

    ],

    '*'=>[

      undef,
      [1,sub {return 0;}],

      [0,sub {my ($x,$y)=@_;return $$x*$$y;}],

    ],

  );

# ---   *   ---   *   ---
# iter tree until operator found
# then restart the loop (!!!)

  TOP:

  $root->cllv();
  $root->idextrav();

  my $high_prio=9999;
  my $high_i=0;

  my @pending=();

  my @ar=@{$root->leaves};
  for my $leaf(@ar) {

    if($matched{"$leaf"}) {next;};

    my $i=$leaf->{-INDEX};

    my $prev=($i>0) ? $ar[$i-1] : undef;
    my $next=($i<$#ar) ? $ar[$i+1] : undef;

    if(@{$leaf->leaves}) {
      push @leaves,$leaf;

    };

# ---   *   ---   *   ---
# check found operands

    my @move=();
    my ($j,$k)=(0,1);

    # node is operator
    if($leaf->value=~ m/${ndel_op}/) {

      # look at previous and next node
      for my $n($prev,$next) {
        if(!defined $n) {next;};

        # n is an operator with leaves
        # or n is not an operator
        my $valid=(

            $n->value=~ m/${ndel_op}/
         && @{$n->leaves}

        );$valid|=!($n->value=~
          m/${del_op}|${ndel_op}/

        );

# ---   *   ---   *   ---

        if($valid) {
          $j|=$k;
          push @move,$n

        };$k++;

      };

# ---   *   ---   *   ---

    };if(@move) {

      my $prio=$h{$leaf->value}->[$j]->[0];

      if(!defined $prio) {
        next;

      };

      push @pending,[$leaf,$j,\@move];

      if($prio<$high_prio) {
        $high_prio=$prio;

        $high_i=$#pending;

      };

    };
  };

# ---   *   ---   *   ---
# reorder nodes and restart

  if(@pending) {

    my $ref=$pending[$high_i];

    my $leaf=$ref->[0];
    my @move=@{$ref->[2]};

    $matched{"$leaf"}=1;
    $leaf->pushlv(0,$root->pluck(@move));
    goto TOP;

  };if(@leaves) {

    $root=shift @leaves;
    goto TOP;

  };

# ---   *   ---   *   ---
# check for ([]) delimiters

};sub delimchk {

  my $self=shift;

  my $ode=lang::ode($self->langkey);
  my $cde=lang::cde($self->langkey);

  my $i=0;for my $leaf(@{$self->leaves}) {

    if(!defined $leaf) {last;};

# ---   *   ---   *   ---

    if($leaf->value=~ m/${ode}/) {

      $leaf->delimbrk($i);
      #$leaf->subdiv();

      my $top=$leaf->leaves->[0];

      #$leaf->pluck($leaf->leaves->[0]);
      #$leaf->leaves->[$i]=$top;

# ---   *   ---   *   ---

    } else {
      #$leaf->subdiv();

    };$i++;
  };

# ---   *   ---   *   ---
# makes a node hierarchy from a
# delimiter-[values]-delimiter sequence

};sub delimbrk {

  my $self=shift;
  my $i=shift;

  my @anchors=();
  my @moved=();

  my $ode=lang::ode($self->langkey);
  my $cde=lang::cde($self->langkey);

  my @ar=@{$self->par->leaves};
  @ar=@ar[$i..$#ar];

  for my $leaf(@ar) {

    if($anchors[-1]) {
      push @{$moved[-1]},$leaf;

    };

# ---   *   ---   *   ---

    if($leaf->value=~ m/${ode}/) {
      push @anchors,$leaf;
      push @moved,[];

    } elsif(

         $leaf->value=~ m/${cde}/
      && @anchors

      ) {

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
    peso::sbl::ndconsume($self,\$i);

  };

};sub exwalk {

  my $self=shift;
  my @leaves=($self);

TOP:

  $self=shift @leaves;

  if(peso::sbl::valid($self->value)) {
    $self->value->ex($self);

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
  my $ndel_op=lang::ndel_ops($self->langkey);
  my $del_op=lang::del_ops($self->langkey);
  my $pesc=lang::pesc($self->langkey);

  # operator data
  my $h=lang::op_prec($self->langkey);

# ---   *   ---   *   ---

TOP:{

  $self=$leaf;
  $self->idextrav();

  if(

  !  $self->value
  || $self->value=~ m/${pesc}/

  ) {goto SKIP;};

  # non delimiter operator match
  my @ar=split m/(${ndel_op}+)/,$self->value;

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
  my $operation=undef;

  for my $op(@q) {

    # skip if already matched
    if(!length $op) {
      $popped++;
      $i++;next;

    };

    if($h->{$op}->[0]=~ m/^[\d]+$/) {
      $operation=$h->{$op};

    } else {

      my $proc=$h->{$op}->[0];
      $operation=
        $h->{$op}->[1]
        ->[$proc->($root,$leaf)];

    };my $j=$operation->[0];

    # get op priority
    if(!defined $j) {
      goto SKIP;

    };

    # compare to previous
    if($j < $highest) {
      $highest=$j;
      $hname=$op;

      $operation=

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
  if($operation->[1]<2) {

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
    if(valid($op_elem)) {

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

  my $ndel_ops=lang::ndel_ops($self->langkey);
  my $del_ops=lang::del_ops($self->langkey);
  my $pesc=lang::pesc($self->langkey);

  my @leafstack;

  my $h=lang::op_prec($self->langkey);
  my @solve=();

# ---   *   ---   *   ---

TOP:{

  $self=$leaf;
  if(!length $self->value) {goto SKIP;};
  if($self->value=~ m/${pesc}/) {
    goto SKIP;

  };

  # is operation
  if($self->value=~ m/^(${ndel_ops}+)/) {

    my $op=$1;
    if(!exists $h->{$op}) {
      goto SKIP;

    };

    my $proc=$h->{$op}->[2];
    my $argval=$self->leaves;

    push @solve,($self,$proc,$argval);

# ---   *   ---   *   ---

  # is value
  } else {

    for my $ref(@nums) {

      my $pat=$ref->[0];
      my $proc=$ref->[1];

      if($self->value=~ m/${pat}/) {
        $self->value($proc->($self->value));
        last;

      } elsif(lang::valid_name(
          $self->value,$self->langkey

      )) {last;};

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

        if($v->value=~ m/${del_ops}/) {
          if($v->value=~ m/\[/) {goto NEXT_OP;};
          push @argval,$v->leaves->[0]->value;

        } elsif(

          lang::valid_name(
            $v->value,$v->langkey

          ) && $proc!=$h->{'->'}->[2]

        ) {

          # names are pointers
          # we don't handle them *here*

          goto NEXT_OP;

        } else {

          # operand reordering
          # done for self->sub->attr chains
          if(

             $proc==$h->{'->'}->[2]
          && $v->value=~ m/@/

          ) {

# wtf?! no need to reorder?????
#            my $old=pop @argval;
            push @argval,($v->value);
#            push @argval,$old;

          # common operand
          } else {push @argval,($v->value);}

        };

      };

# ---   *   ---   *   ---

      for my $arg(@{$args}) {
        if($arg->value eq '[') {goto NEXT_OP;};
        for my $sleaf(@{$arg->leaves}) {
          if($sleaf->value eq '[') {goto NEXT_OP;};

        };

      };

      if(!defined $proc) {

      goto NEXT_OP;

      };

      my $result=$proc->(@argval);
      $node->value($result);
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

  my $pesc=lang::pesc($self->langkey);
  my $types=lang::types($self->langkey);

# ---   *   ---   *   ---
# iter leaves

  for my $leaf(@{$self->leaves}) {

    $leaf->findptrs();

    # skip $:escaped;>
    if($leaf->value=~ m/${pesc}/) {
      next;

    };

    # solve/fetch non-numeric values
    if(lang::valid_name(
        $leaf->value,$leaf->langkey

      ) && !(exists $types->{$leaf->value()})

    ) {

      $leaf->value(peso::ptr::fetch($leaf->value));

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
    printf $self->value."\n";
    $depth=0;

  };

  # iter children
  for my $node(@{ $self->leaves }) {

    printf ''.(
      '.  'x($depth).'\-->'.
#      '['.$node->{-INDEX}.']: '.
      $node->value


    )."\n";$node->prich($depth+1);

  };

# ---   *   ---   *   ---

  if(@{ $self->leaves }) {
    printf '.  'x($depth)."\n";

  };

};

# ---   *   ---   *   ---

