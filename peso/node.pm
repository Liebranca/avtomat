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
  use Scalar::Util qw/blessed/;

# ---   *   ---   *   ---

sub valid {

  my $node=shift;if(

     blessed($node)
  && $node->isa('peso::node')

  ) {

    return 1;
  };return 0;

};

# ---   *   ---   *   ---
# constructors

sub new_frame($) {
  return peso::node::frame::create(shift);

};

# in: parent,val
# make child node or create a new tree
sub nit($$$) {

  my ($frame,$parent,$val)=@_;

  # tree/root handle
  my %tree=(

    -ROOT=>undef,

  );my $tree_id;

# ---   *   ---   *   ---

  # make new tree if no ancestor
  if(!(defined $parent)) {

    my @ar=@{ $frame->{-TREES} };
    $tree_id=@ar;

    if(defined $frame->{-ANCHOR}) {
      $tree{-ROOT}=undef;

    };

    push @{ $frame->{-TREES} },\%tree;

# ---   *   ---   *   ---

  # ... or fetch from id
  } else {
    $tree_id=$parent->{-ROOT};
    %tree=%{ $frame->{-TREES}->[$tree_id] };

  # make node instance
  };my $node=bless {

    -VALUE=>$val,
    -LEAVES=>[],

    -ROOT=>$tree_id,
    -PAR=>undef,
    -INDEX=>0,

    -FRAME=>$frame,

  },'peso::node';

# ---   *   ---   *   ---

  # add leaf if ancestry
  if(defined $parent) {

    $node->{-INDEX}=$parent->idextrav();

    push @{ $parent->leaves },$node;
    $node->{-PAR}=$parent;

  } else {
    $tree{-ROOT}=$node;

  };return $node;

};

# ---   *   ---   *   ---
# getters

sub frame {return (shift)->{-FRAME};};
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

sub dup($$) {

  my ($self,$root)=@_;
  my $frame=$self->frame;

  my @leaves=();

  my $copy=$frame->nit($root,$self->value);

  for my $leaf(@{$self->leaves}) {
    $leaf->dup($copy);

  };

  return $copy;

};

# ---   *   ---   *   ---

sub group($$;$) {

  my ($self,$idex,$sub)=@_;

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

sub walkup($;$) {

  my ($self,$top)=@_;

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

  my ($self,$pos,$sz)=@_;
  my $frame=$self->frame;

  for my $i(0..$sz-1) {
    $frame->nit($self,'BLANK');

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
      $node=mksep();

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
sub cllv($) {

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

sub tokenize($$) {

  my ($self,$exp)=@_;
  my $frame=$self->frame;
  my $lang=$frame->master->lang;

  # patterns
  my $ops=$lang->ops;
  my $del_op=$lang->del_ops;
  my $ndel_op=$lang->ndel_ops;

  my $ode=$lang->ode;
  my $cde=$lang->cde;
  my $pesc=$lang->pesc;

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
      $frame->nit($self,$elem);

    };
  };
};

# ---   *   ---   *   ---
# clump fields of arguments together

sub agroup($) {

  my $self=shift;
  my $frame=$self->frame;
  my $lang=$frame->master->lang;

  my @shifts=();
  my $i=0;

# ---   *   ---   *   ---

  my $keyword=$lang->keywords;

  my @anchors=();
  my @trash=();

  my @leaves=@{$self->leaves};
  TOP:my $leaf=shift @leaves;

# ---   *   ---   *   ---

# INSERT LANG RULES HERE

# ---   *   ---   *   ---

  if($leaf->value=~ m/^${keyword}/) {
    $leaf->{-VALUE}=~ s/\s*\*/ ptr/sg;

  } elsif($leaf->value=~ m/${keyword}/) {
    $leaf->{-VALUE}=~ s/\*\s*/ptr /sg;

  };

# ---   *   ---   *   ---

  if($leaf->value eq ',') {
    push @trash,$leaf;
    pop @anchors;

  };

# ---   *   ---   *   ---

  if($anchors[-1]) {

    my $anchor=$anchors[-1]->[0];
    my $argc=\$anchors[-1]->[1];

    $frame->nit($anchor,$leaf->value);
    push @trash,$leaf;

    $$argc--;

    if(!$$argc) {
      pop @anchors;

    };

  };

# ---   *   ---   *   ---

  if(exists $lang->types->{$leaf->value}) {
    push @anchors,[$leaf,$lang->types->{$leaf->value}];

  };

  unshift @leaves,@{$leaf->leaves};

  if(@leaves) {goto TOP;};
  END:$self->pluck(@trash);

  $self->delimchk();

# ---   *   ---   *   ---
# expands the tree to solve expressions

};sub subdiv($) {

  my $self=shift;
  my $frame=$self->frame;
  my $lang=$frame->master->lang;

  my $ndel_op=$lang->ndel_ops;
  my $del_op=$lang->del_ops;

  my %matched=();

  my $root=$self;
  my @leaves=();

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

      my $prio

        =$lang->op_prec
        ->{$leaf->value}
        ->[$j]->[0]

      ;

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

};sub delimchk($) {

  my $self=shift;
  my $frame=$self->frame;
  my $lang=$frame->master->lang;

  my $ode=$lang->ode;
  my $cde=$lang->cde;

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

};sub delimbrk($$) {

  my ($self,$i)=@_;
  my $frame=$self->frame;
  my $lang=$frame->master->lang;

  my @anchors=();
  my @moved=();

  my $ode=$lang->ode;
  my $cde=$lang->cde;

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

#  my $i=0;while($i<@{$self->leaves}) {
#    peso::sbl::ndconsume($self,\$i);
#
#  };

};sub exwalk {

#  my $self=shift;
#  my @leaves=($self);
#
#TOP:
#
#  $self=shift @leaves;
#
#  if(peso::sbl::valid($self->value)) {
#    $self->value->ex($self);
#
#  } else {
#    push @leaves,@{$self->leaves};
#
#  };if(@leaves) {goto TOP;};

};

# ---   *   ---   *   ---

# in: node to replace self by
# replaces a node in the hierarchy

sub repl($$) {

  my ($self,$other)=@_;

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

sub idextrav($) {

  my $self=shift;
  my $i=0;

  for my $child(@{$self->leaves}) {
    $child->{-INDEX}=$i;$i++;

  };return $i;

};

# ---   *   ---   *   ---
# DEPRECATED

# in: value conversion table
# solve expressions in tree

sub collapse {

  my $self=shift;
  my $frame=$self->frame;
  my $lang=$frame->master->lang;

  my @nums=@{$lang->numcon()};

  my $leaf=$self;

  my $ndel_ops=$lang->ndel_ops;
  my $del_ops=$lang->del_ops;
  my $pesc=$lang->pesc;

  my @leafstack;

  my $h=$lang->op_prec;
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

      } elsif($lang->valid_name(
          $self->value

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

          $lang->valid_name(
            $v->value

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

sub findptrs($) {

  my $self=shift;
  my $frame=$self->frame;
  my $lang=$frame->master->lang;

  my $fr_ptr=$frame->master->ptr;

  my $pesc=$lang->pesc;
  my $types=$lang->types;

# ---   *   ---   *   ---
# iter leaves

  for my $leaf(@{$self->leaves}) {

    $leaf->findptrs();

    # skip $:escaped;>
    if($leaf->value=~ m/${pesc}/) {
      next;

    };

    # solve/fetch non-numeric values
    if($lang->valid_name(
        $leaf->value

      ) && !(exists $types->{$leaf->value()})

    ) {

      $leaf->value($fr_ptr->fetch($leaf->value));

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

package peso::node::frame;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# getters

sub master {return (shift)->{-MASTER};};

# ---   *   ---   *   ---
# constructors

sub nit($$$) {
  return peso::node::nit(
    $_[0],$_[1],$_[2],

  );

};sub create($) {

  my $master=shift;

  my $frame=bless {

    -TREES=>[],

    -DEPTH=>[],
    -LDEPTH=>0,
    -ANCHOR=>undef,

    -BLOCKS=>undef,
    -NUMCOM=>undef,

    -MASTER=>$master,

  },'peso::node::frame';

  return $frame;

};

# ---   *   ---   *   ---
1; # ret
