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
    -VALUE_TYPE=>0x00,

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

sub value_type($) {return (shift)->{-VALUE_TYPE};};

sub ances($$) {

  my ($self,$join)=@_;

  my $anchor=$self;
  my $s='';

TOP:

  $s=$anchor->value.$s;
  if($anchor->par) {

    $s=$join.$s;
    $anchor=$anchor->par;
    goto TOP;

  };

  return $s;

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

sub fieldn($$) {

  my ($self,$i)=@_;
  my $field=($self->branches_with("field_$i"))[0];

  return $field->leaves->[$i];

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

  my @ar=split m/([^\s]*)\s+/,$exp;
  my $i=0;while(@ar) {
    my $elem=shift @ar;

    if(defined $elem && length $elem) {

      my $node=$frame->nit($self,"field_$i");

# ---   *   ---   *   ---

      $elem=~ s/(${ops}|${del_op})/ $1 /sg;

      for my $tok(split m/([^\s]*)\s+/,$elem) {

        if(defined $tok && length $tok) {
          $frame->nit($node,$tok);

        };
      };$i++;

# ---   *   ---   *   ---

    };
  };

# ---   *   ---   *   ---
# classify tokens

  for my $leaf(@{$self->leaves}) {

    $leaf->{-VALUE_TYPE}
      =$lang->classify($leaf->value);

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

  $self->cllv();

  my @leaves=@{$self->leaves};
  TOP:my $leaf=shift @leaves;

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

  $leaf->cllv();
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

  my $cde=$lang->cde;

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
    if(exists $lang->op_prec->{$leaf->value}) {

      # look at previous and next node
      for my $n($prev,$next) {
        if(!defined $n) {$k++;next;};

        # n is an operator with leaves
        # or n is not an operator
        my $valid=(
            ($n->value=~ m/${ndel_op}|${del_op}/)
         && @{$n->leaves}

        )!=0;$valid|=!($n->value=~
          m/${del_op}|${ndel_op}/

        );

# ---   *   ---   *   ---

        if($valid) {

          #if($n=~ m/$cde/) {$n=$n->par;};

          $j|=$k;
          push @move,$n;

        };$k++;

      };

# ---   *   ---   *   ---

    };if(@move) {

      my $prio

        =$lang->op_prec
        ->{$leaf->value}
        ->[$j-1]->[0]

      ;

      if(!defined $prio) {
        next;

      };

      push @pending,[$leaf,$j-1,\@move];

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
    my $idex=$ref->[1];

    my @move=@{$ref->[2]};

    $leaf->value(bless {

      op=>$leaf->value,
      idex=>$idex,

    },'node_op');

    $matched{"$leaf"}=1;
    $leaf->pushlv(0,$root->pluck(@move));
    goto TOP;

  };if(@leaves) {

    $root=shift @leaves;
    goto TOP;

  };

# ---   *   ---   *   ---
#:*;> TODO
#:*;>
#:*;> half re-implementation :c
#:*;>
#:*;> - lacking conversions for literals
#:*;>
#:*;> - lacking a good way to find the right
#:*;>   version of operator to execute

};sub collapse($) {

  my $self=shift;
  my $lang=$self->frame->master->lang;
  my $op_prec=$lang->op_prec;
  my $del_op=$lang->del_ops;

  my @leaves=($self);
  my @solve=();

# ---   *   ---   *   ---
# collect pending operations

  do {

    $self=shift @leaves;

    if($self->value=~ m/^node_op=HASH/) {
      push @solve,$self;

    };unshift @leaves,@{$self->leaves};

  } while(@leaves);

# ---   *   ---   *   ---
# handle operations bottom to top
# i.e. first in last out

  while(@solve) {

    my $self=pop @solve;

    my $op=$op_prec->{$self->value->{op}};
    my $idex=$self->value->{idex};

    my @args=$self->pluck(@{$self->leaves});
    for my $arg(@args) {$arg=\$arg->value;};

    $self->value($op->[$idex]->[1]->(@args));

    if($self->par->value=~ m/^${del_op}$/) {
      $self->par->repl($self);

    };
  };

# ---   *   ---   *   ---

};sub defield($) {

  my $self=shift;
  my $i=0;while($i<@{$self->leaves}) {

    my $field=$self->fieldn($i);
    my @ar=$field->pluck(@{$field->leaves});

    $field->value($ar[0]->value);
    $i++;

  };

# ---   *   ---   *   ---
# check for ([]) delimiters

};sub delimchk($) {

  my $self=shift;
  my $frame=$self->frame;
  my $lang=$frame->master->lang;

  my $ode=$lang->ode;
  my $cde=$lang->cde;

  my @leaves=($self);
  TOP:$self=shift @leaves;

  my $i=0;for my $leaf(@{$self->leaves}) {

    if(!defined $leaf) {last;};

# ---   *   ---   *   ---

    if($leaf->value=~ m/${ode}/) {
      $leaf->delimbrk($i);

    };$i++;

  };

  unshift @leaves,@{$self->leaves};
  if(@leaves) {goto TOP;};

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
    $other->{-PARENT}=$self->par;
    $ref->[$i]=$other;

  };

  $self->par->cllv();
  $self->par->idextrav();

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

sub hashtree {

  my $h=shift;

  my $frame=new_frame(undef);

  my @pending=();
  my $leaf=undef;

TOP:for my $key(keys %$h) {

    my $value=$h->{$key};
    my $node=$frame->nit($leaf,$key);

    if(lang::is_hashref($value)) {
      push @pending,([$node,$value]);

    };

  };

  if(@pending) {

    ($leaf,$h)=@{(shift @pending)};
    goto TOP;

  };

  return $frame->{-TREES}->[-1]->{-ROOT};

};

# ---   *   ---   *   ---
# gives list of branches holding value

sub branches_with($$) {

  my ($self,$lookfor)=@_;
  my $anchor=$self;

  my @leaves=();
  my @found=();

# ---   *   ---   *   ---
# iter leaves

TOP:

  if(!@{$anchor->leaves}) {goto SKIP;};

  for my $leaf(@{$anchor->leaves}) {

    # accept branch if value found in leaves
    if($leaf->value=~ m/${lookfor}/) {
      push @found,$anchor;
      last;

    };
  };

  push @leaves,@{$anchor->leaves};

# ---   *   ---   *   ---
# continue if children pending

SKIP:

  if(@leaves) {

    $anchor=shift @leaves;
    goto TOP;

  };

# ---   *   ---   *   ---
# return matches

END:
  return @found;

};

# ---   *   ---   *   ---
# gives list of branches starting with value

sub branches_in($$) {

  my ($self,$lookfor)=@_;
  my $anchor=$self;

  my @leaves=();
  my @found=();

# ---   *   ---   *   ---
# check node

TOP:

  if(!@{$anchor->leaves}) {goto SKIP;};

  if($anchor->value=~ m/${lookfor}/) {
    push @found,$anchor;

  };

  push @leaves,@{$anchor->leaves};

# ---   *   ---   *   ---
# go to next node if pending

SKIP:

  if(@leaves) {

    $anchor=shift @leaves;
    goto TOP;

  };

# ---   *   ---   *   ---
# return matches

END:
  return @found;

};

# ---   *   ---   *   ---

sub plain_arr(@) {

  my @tree=@_;
  my @result=();

  for my $branch(@tree) {

    for my $leaf(@{$branch->leaves}) {
      push @result,$leaf->value;

    };
  };

  return @result;

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

    my $v=($self->value=~ m/node_op=HASH/)
      ? $self->value->{op}
      : $self->value
      ;

    print $v."\n";
    $depth=0;

  };

  # iter children
  for my $node(@{ $self->leaves }) {

    my $v=($node->value=~ m/node_op=HASH/)
      ? $node->value->{op}
      : $node->value
      ;

    print ''.(
      '.  'x($depth).'\-->'.$v

    )."\n";

    $node->prich($depth+1);

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
