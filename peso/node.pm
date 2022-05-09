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

# in:self,pattern,string
# branch out node from pattern split
sub splitlv {

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

  { my @ar=split m/([^\s]*)\s+/,$exp;

    while(@ar) {
      my $elem=shift @ar;
      if(defined $elem) {
        push @elems,$elem;

      };
    };

# ---   *   ---   *   ---

  };{

    # iter split'd arr to find bounds

    my @filt=('$:%%join;>');
    my $s='';

    my @separator=(
      '$:/join;>',
      '$:%%join;>'

    );

    my $i=0;for my $e(@elems) {

# ---   *   ---   *   ---

TOP:

    # skip null str
    if(!length $e) {goto SKIP;};

    # get left and rightmost chars of elem
    my ($ol,$or)=(split '',$e)[0,-1];

    # leftmost char fallback on undef right
    if(!defined $or) {
      $or=$ol;

    };

# ---   *   ---   *   ---
# get left and rightmost chars of last

    my ($pl,$pr)=(

      split '',
        $elems[$i-1]

    )[0,-1];

# ---   *   ---   *   ---
# use last accepted as fallback

    if(!defined $pl) {

      # find last non-escape elem
      my $j=-1;
      while(defined $filt[$j]) {

        my $f=$filt[$j];
        if($f=~ m/${pesc}/) {
          $j--;next;

        };last;

      };

# ---   *   ---   *   ---
# use if not undef

      if(defined $filt[$j]) {
        ($pl,$pr)=(

          split '',
            $filt[$j]

        )[0,-1];

      # or dont use at all
      } else {
        ($pl,$pr)=('','');

      };

    };

# ---   *   ---   *   ---
# leftmost char fallback on undef right

    if(!defined $pr) {
      $pr=$pl;

    };

# ---   *   ---   *   ---
# is not operator

    if(!($ol=~ m/${ops}/)) {

      # put separator if
      my $cut=(length $pr) && (

        # close delimiter : non operator
        ($pr=~ m/${cde}/)

        ||

        # non operator : non operator or comma
        !($pr=~ m/${ops}|,}/)

      );if($cut) {goto APPEND;};

# ---   *   ---   *   ---

    # is delimiter
    } elsif($ol=~ peso::decls::ode
    || $ol=~ peso::decls::cde

    ) {

      my $cut=0;

      # put separator if
      if($ol=~ m/${ode}/) {

        $cut=(

          # non operator or comma : open delimiter
          !($pr=~ m/${ops}|,/) && $pr

        );

# ---   *   ---   *   ---

      };if($cut) {

        # accept elements and separate
        if($s) {push @filt,$s;};
        push @filt,@separator;

      } elsif(length $s) {push @filt,$s;};$s='';

      # make it its own element
      push @filt,$ol;
      $e=~ s/\Q${ol}//;

      # read remain
      goto TOP;

    } elsif(peso::decls::is_str($e)) {
      goto APPEND;

    };

# ---   *   ---   *   ---

    goto SKIP;


# ---   *   ---   *   ---

APPEND:

    if(length $s) {
      push @filt,$s;

    };if($filt[-1] ne '$:%%join;>') {
      push @filt,@separator;

    };$s='';

SKIP:

    $s.=$e;
    $i++;

  };

# ---   *   ---   *   ---

  if(length $s) {push @filt,$s;};

    push @filt,'$:/join;>';
    @elems=@filt;

  };

# ---   *   ---   *   ---

  # split string at pattern
  #for my $sym(split m/(${pat})/,$exp) {
  for my $sym(@elems) {

    if(!length($sym)) {next;};

    # eliminate match
    $exp=~ m/^(.*)\Q${sym}/;
    if(defined $1 && length $1) {
      $exp=~ s/\Q${1}//;

    # space strip
    };$sym=~ s/\s+//sg;

    if($sym eq '$:%%join;>'
    || $sym eq '$:/join;>'

    ) {

      my $node=$self->nit($sym);
      next;

    };

# ---   *   ---   *   ---

  # subdivide by delimiters
  if( $sym=~ m/^(${ode})/ ) {

    my $c=$1;
    if($c eq '(') {

      push @anch,$anch[-1]->oparn(undef);
      $exp_depth_a++;

    } elsif($c eq '[') {
      push @anch,$anch[-1]->obrak(undef);
      $exp_depth_a++;

    };next;
  };

# ---   *   ---   *   ---

  if($exp_depth_a) {

    if($sym eq ')') {

      $anch[-1]->cparn(undef);
      pop @anch;

      $exp_depth_a--;

      next;

    } elsif($sym eq ']') {

      $anch[-1]->cbrak(undef);
      pop @anch;

      $exp_depth_a--;

      next;

    };

  };

# ---   *   ---   *   ---

    # make new node from token
    if(!length $sym) {next;$sym='$:cut;>';};
    my $node=$anch[-1]->nit($sym);

  };

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

# use peso rules for grouping tokens
sub agroup {

  my $self=shift;

  my @buf=();
  my @dst=();

  my $ode=peso::decls::ode;
  my $cde=peso::decls::cde;

  my $delims=${ode}.'|'.${cde};

# ---   *   ---   *   ---

  my @chest=();
  my @trash=();

  my $anchor=$self;

  # branch out at joins
  for my $node(@{ $self->leaves }) {

    my $sym=$node->val;

    # group all nodes inside wrap
    if($sym eq '$:%%join;>') {

      $anchor=$node;
      $node->{-VAL}='$:group;>';

    # ^ wrap close
    } elsif($sym eq '$:/join;>') {
      $anchor->pushlv(0,@chest);
      @chest=();

      push @trash,$node;

# ---   *   ---   *   ---

    # accumulate elements
    } else {

      if(0>index $sym,',') {
        push @chest,$node;

      # comma found
      } else {

        my @left=split ',',$sym;
        while(@left) {
          my $tail=shift @left;

# ---   *   ---   *   ---

          # compound element
          if(@chest && !$anchor) {

            my $old=$anchor;
            $anchor=$anchor->nit('$:group;>');

            $anchor->pushlv(0,@chest);
            @chest=();

            $anchor->nit($tail);
            $anchor=$old;

# ---   *   ---   *   ---

          # common element
          } elsif($tail) {

            # push self
            push @chest,
              peso::node::nit(undef,$tail);

            # push leftovers
            while(@left) {
              push @chest,peso::node::nit(
                undef,
                shift @left

              );
            };

          # discard explored node
          };push @trash,$node;
        };

# ---   *   ---   *   ---

      };
    };

# ---   *   ---   *   ---

  };if(@chest) {
    $anchor->pushlv(1,@chest);

  };

  for my $child(@{ $self->leaves }) {
    if(!@{ $child->leaves }) {
      push @trash,$child;

    };

  };

  $self->pluck(@trash);

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
