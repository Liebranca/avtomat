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
package node;
  use strict;
  use warnings;

my %CACHE=(

  -TREES=>[],
  -NAMES=>'[_a-zA-Z][_a-zA-Z0-9]',

# ---   *   ---   *   ---

  -OPS=>'[^\s_A-Za-z0-9\.:\\\\]',

  -ODE=>'[\(\[\{]',
  -CDE=>'[\}\]\)]',

  -DEL_OPS=>'[\{\[\(\)\]\}\\\\]',
  -NDEL_OPS=>'[^\s_A-Za-z0-9\.:\{\[\(\)\]\}\\\\]',

# ---   *   ---   *   ---

  -DEPTH=>[],
  -LDEPTH=>0,
  -ANCHOR=>undef,

);

# ---   *   ---   *   ---

  $CACHE{-OP_PREC}={

    '*^'=>[0,2,sub {return (shift)**(shift);}],
    '*'=>[1,2,sub {return (shift)*(shift);}],
    '/'=>[2,2,sub {return (shift)/(shift);}],

    '++'=>[3,1,sub {return (shift)+1;}],
    '+'=>[4,2,sub {return (shift)+(shift);}],
    '--'=>[5,1,sub {return (shift)-1;}],
    '-'=>[6,2,sub {return (shift)-(shift);}],

# ---   *   ---   *   ---

    '?'=>[7,1,sub {return int((shift)!=0);}],
    '!'=>[8,1,sub {return int(!(shift));}],
    '~'=>[9,1,sub {return ~int(shift);}],

    '<<'=>[10,2,sub {

      return int(int(shift)<< int(shift));

    }],

    '>>'=>[11,2,sub {

      return int(int(shift)>> int(shift));

    }],

# ---   *   ---   *   ---

    '|'=>[12,2,sub {

      return int(int(shift)| int(shift));

    }],

    '^'=>[13,2,sub {

      return int(shift)^int(shift);

    }],

    '&'=>[14,2,sub {

      return int(int(shift)& int(shift));

    }],

    '<'=>[15,2,sub {

      return int((shift)<(shift));

    }],

    '<='=>[15,2,sub {

      return int((shift)<=(shift));

    }],

    '>'=>[16,2,sub {

      return int((shift)>(shift));

    }],

    '>='=>[16,2,sub {

      return int((shift)>=(shift));

    }],

# ---   *   ---   *   ---

    '||'=>[17,2,sub {

      return int(
           (int(shift)!=0)
        || (int(shift)!=0)

      );

    }],

    '&&'=>[18,2,sub {

      return int(
           int((shift)!=0)
        && int((shift)!=0)

      );

    }],

    '=='=>[19,2,sub {
      return int((shift)==(shift));

    }],

    '!='=>[20,2,sub {
      return int((shift)!=(shift));

    }],

    '->'=>[21,2,sub {
      return (shift).'@'.(shift);

    }],

  };

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

      #printf "$val\n";

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

  },'node';

# ---   *   ---   *   ---

  # add leaf if $self
  if(defined $self) {

    $node->{-INDEX}=$self->idextrav();

    push @{ $self->{-LEAVES} },$node;
    $node->{-PAR}=$self;

  } else {
    $tree{-ROOT}=$node;

  };return $node;

};

sub mksep {

  return bless {

    -VAL=>'$:cut;>',
    -LEAVES=>[],

    -ROOT=>0,
    -PAR=>undef,

  },'node';

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
  my @leaves=$self->pluck(@{ $self->{-LEAVES} });
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

sub walkup {

  my $self=shift;
  my $top=shift;

  if(!defined $top) {
    $top=-1;

  };

  my $node=$self->{-PAR};
  my $i=0;

  while($top<$i) {
    my $par=$node->{-PAR};
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

    my $par=$node->{-PAR};

    $node->{-ROOT}=$self->{-ROOT};
    $node->{-PAR}=$self;

    push @{ $self->{-LEAVES} },$node;

    if($par && $par!=$node->{-PAR}) {
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

    $i<@{ $self->{-LEAVES} };
    $i++

  ) {

    # push only nodes that arent plucked
    my $node=$self->{-LEAVES}->[$i];
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
  my $pat=shift;
  my $exp=shift;

  my $exp_depth_a=0;
  my $exp_depth_b=0;

  my @anch=($self);

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

    my $op=$CACHE{-OPS};
    my $del_op=$CACHE{-DEL_OPS};
    my $ndel_op=$CACHE{-NDEL_OPS};

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

    # use last accepted as fallback
    if(!defined $pl) {
      ($pl,$pr)=(

        split '',
          $filt[-1]

      )[0,-1];

    };

    # leftmost char fallback on undef right
    if(!defined $pr) {
      $pr=$pl;

    };

# ---   *   ---   *   ---

    # is not operator
    if(!($ol=~ m/${op}/)) {

      # put separator if
      my $cut=(

        # close delimiter : non operator
        ($pr=~ m/${CACHE{-CDE}}/)

        ||

        # non operator : non operator or comma
        !($pr=~ m/${op}|,}/)

      );if($cut) {goto APPEND;};

# ---   *   ---   *   ---

    # is delimiter
    } elsif($ol=~ $CACHE{-ODE}
    || $ol=~ $CACHE{-CDE}

    ) {

      my $cut=0;

      # put separator if
      if($ol=~ m/$CACHE{-ODE}/) {

        $cut=(

          # non operator or comma : open delimiter
          !($pr=~ m/${op}|,/)

        );

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

    };

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
  if( $sym=~ m/^(${CACHE{-ODE}})/ ) {

    my $c=$1;
    if($c eq '(') {

      push @anch,$anch[-1]->oparn(undef);
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

  my $ref=$self->{-PAR}->{-LEAVES};
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
    @{ $self->{-LEAVES} }

  # skip removed nodes
  ) { if(!$leaf) {next;};

      # iter node array
      my $j=0;for my $node(@ar) {

        # skip already removed ones
        if(!$node) {$j++;next;};

# ---   *   ---   *   ---

        # node is in remove list
        if($leaf->{-VAL} eq $node->{-VAL}) {

          # save the removed nodes
          push @plucked,$self->{-LEAVES}->[$i];

          # remove from list and leaves
          $ar[$j]=undef;
          $self->{-LEAVES}->[$i]=undef;

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

  my $delims=${CACHE{-ODE}}.'|'.${CACHE{-CDE}};

# ---   *   ---   *   ---

  my @chest=();
  my @trash=();

  my $anchor=$self;

  # branch out at joins
  for my $node(@{ $self->{-LEAVES} }) {

    my $sym=$node->{-VAL};

    # group all nodes inside wrap
    if($sym eq '$:%%join;>') {

      $anchor=$node;
      $node->{-VAL}='L';

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
          if(@chest) {

            my $old=$anchor;
            $anchor=$anchor->nit('$:group;>');

            $anchor->pushlv(0,@chest);
            @chest=();

            $anchor->nit($tail);
            $anchor=$old;

# ---   *   ---   *   ---

          # common element
          } else {

            # push self
            push @chest,
              node::nit(undef,$tail);

            # push leftovers
            while(@left) {
              push @chest,node::nit(
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

  for my $child(@{ $self->{-LEAVES} }) {
    if(!@{ $child->{-LEAVES} }) {
      push @trash,$child;

    };

  };

  $self->pluck(@trash);

};

# ---   *   ---   *   ---

sub idextrav {

  my $self=shift;
  my $i=0;

  for my $child(@{$self->{-LEAVES}}) {
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
  my $ndel_op=$CACHE{-NDEL_OPS};

  # operator data
  my $h=$CACHE{-OP_PREC};

# ---   *   ---   *   ---

TOP:{

  $self=$leaf;
  $self->idextrav();

  if(!$self->{-VAL}) {goto SKIP;};

  # non delimiter operator match
  my @ar=split m/(${ndel_op}+)/,$self->{-VAL};

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
    $elems[$hidex]=$self->{-PAR}->{-LEAVES}
    ->[$self->{-INDEX}-1];

  };if(!length $elems[$hidex+1]) {
    $elems[$hidex+1]=$self->{-PAR}->{-LEAVES}
    ->[$self->{-INDEX}+1];

  };

  my $lhand=$elems[$hidex];
  my $rhand=$elems[$hidex+1];

  my $node=$self->{-PAR}->nit($hname);

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
    if((index $op_elem,'node=HASH')>=0) {

      # operand is at root level
      if($op_elem->{-PAR} eq $node->{-PAR}) {
        push @mov,$op_elem;

      # ^ or further down the chain
      } else {
        push @mov,$op_elem->{-PAR};

      };

    # element is a string
    } else {
      $node->nit($op_elem);

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
  $self->{-PAR}->pluck($nodes[-1]);
  $self->repl($nodes[-1]);

# ---   *   ---   *   ---

};SKIP:{

  $self->idextrav();

  if(!@leafstack && !@{ $self->{-LEAVES} }) {
    return;

  };

  push @leafstack,@{ $self->{-LEAVES} };
  $leaf=pop @leafstack;

  @nodes=();
  goto TOP;

}}};

# ---   *   ---   *   ---

# in: value conversion table
# solve expressions in tree

sub collapse {

  my $self=shift;
  my @nums=@{ $_[0] };shift;

  my $leaf=$self;
  my $ndel_op=$CACHE{-NDEL_OPS};

  my @leafstack;

  my $h=$CACHE{-OP_PREC};
  my @solve=();

# ---   *   ---   *   ---

TOP:{

  $self=$leaf;
  if(!length $self->{-VAL}) {goto SKIP;};

  # is operation
  if($self->{-VAL}=~ m/(${ndel_op}+)/) {

    my $op=$1;
    my $proc=$h->{$op}->[2];
    my $argval=$self->{-LEAVES};

    push @solve,($self,$proc,$argval);

# ---   *   ---   *   ---

  # is value
  } else {

    for my $ref(@nums) {

      my $pat=$ref->[0];
      my $proc=$ref->[1];

      if($self->{-VAL}=~ m/${pat}/) {
        $self->{-VAL}=$proc->($self->{-VAL});
        last;

      } elsif($self->{-VAL}=~
          m/${CACHE{-NAMES}}*/

      ) {last;};

    };
  };

};

# ---   *   ---   *   ---

SKIP:{
  if(!@leafstack && !@{ $self->{-LEAVES} }) {

    while(@solve) {

      my $argval=pop @solve;
      my $proc=pop @solve;
      my $node=pop @solve;

      my @argval=();
      for my $v(@{$argval}) {

        if($v->{-VAL}=~ m/${CACHE{-DEL_OPS}}/) {
          push @argval,$v->{-LEAVES}->[0]->{-VAL};

        } elsif($self->{-VAL}=~
            m/${CACHE{-NAMES}}*/

        ) {

          # names are pointers
          # the system is not ready for that ;>
          # just ignore pointers for now

          goto NEXT_OP;

        } else {

          push @argval,($v->{-VAL});

        };

      };

      my $result=$proc->(@argval);
      $node->{-VAL}=$result;
      $node->pluck(@{$argval});

      NEXT_OP:

    };return;

  };

  push @leafstack,@{ $self->{-LEAVES} };
  $leaf=pop @leafstack;

  goto TOP;

}};

# ---   *   ---   *   ---

# print node leaves
sub prich {

  # instance
  my $self=shift;
  my $depth=shift;

# ---   *   ---   *   ---

  # print head
  if(!defined $depth) {
    printf "$self->{-VAL}\n";
    $depth=0;

  };

  # iter children
  for my $node(@{ $self->{-LEAVES} }) {

    printf ''.(
      '.  'x($depth).'\-->'.
#      '['.$node->{-INDEX}.']: '.
      $node->{-VAL}


    )."\n";$node->prich($depth+1);

  };

# ---   *   ---   *   ---

  if(@{ $self->{-LEAVES} }) {
    printf '.  'x($depth)."\n";

  };

};

# ---   *   ---   *   ---
