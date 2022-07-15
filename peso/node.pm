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

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use English qw(-no_match_vars);
  use Scalar::Util qw/blessed/;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;
  use lang;

  use lib $ENV{'ARPATH'}.'/lib/hacks';
#  use inline;
  use shwl;

# ---   *   ---   *   ---
# info

  our $VERSION=v3.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $OPERATOR=>qr{
    node_op=HASH\(0x[0-9a-f]+\)

  }x;

# ---   *   ---   *   ---

sub valid($node) {
  return arstd::valid($node);

};

# ---   *   ---   *   ---
# constructors

sub new_frame(@args) {
  return peso::node::frame::create(@args);

};

# in: parent,val
# make child node or create a new tree
sub nit($frame,$parent,$val,%opts) {

  # opt defaults
  $opts{unshift_leaves}//=0;

# ---   *   ---   *   ---

  # make node instance
  my $node=bless {

    value=>$val,
    value_type=>0x00,

    leaves=>[],
    parent=>undef,
    idex=>0,

    frame=>$frame,

  },'peso::node';

# ---   *   ---   *   ---

  # add leaf if ancestry
  if(defined $parent) {

    if($opts{unshift_leaves}) {
      unshift @{$parent->{leaves}},$node;

    } else {
      push @{$parent->{leaves}},$node;

    };

    $node->{parent}=$parent;
    $parent->idextrav();

# ---   *   ---   *   ---

  };

   return $node;

};

# ---   *   ---   *   ---

sub root($self) {

  my $root=$self;

  while(defined $root->{parent}) {
    $root=$root->{parent};

  };

  return $root;

};

# ---   *   ---   *   ---
# getters

sub ances($self,$join) {

  my $anchor=$self;
  my $s=$NULLSTR;

TOP:

  $s=$anchor->{value}.$s;
  if($anchor->{parent}) {

    $s=$join.$s;
    $anchor=$anchor->{parent};

    goto TOP;

  };

  return $s;

};

# ---   *   ---   *   ---
# makes copy of instance

sub dup($self,$root=undef) {

  my $frame=$self->{frame};
  my @leaves=();

  my $copy=$frame->nit($root,$self->{value});

  for my $leaf(@{$self->{leaves}}) {
    $leaf->dup($copy);

  };

  return $copy;

};

# ---   *   ---   *   ---
# returns first match of field_%i

sub fieldn($self,$i) {
  my $re=qr{^fields_$i$};
  my $field=$self->branch_with($re);

  return $field->{leaves}->[$i];

# ---   *   ---   *   ---
# ^same, returns whole list

};sub fieldsn($self,$i) {
  my $re=qr{^fields_$i$};
  my @fields=$self->branches_in($re);
  return @fields;

};

# ---   *   ---   *   ---

sub group($self,$idex,$subidex=undef) {

  my $out=undef;

  # errchk
  if(!@{$self->{leaves}}) {

    arstd::errout(

      "Node <%s> has no children\n",

      args=>[$self->{value}],
      lvl=>$WARNING,

    );

    goto FAIL;

  };

# ---   *   ---   *   ---
# get nth group

  my $group=$self->{leaves}->[$idex];

  # get nth element in group
  if(defined $subidex) {

    my $node=$group->{leaves}->[$subidex];
    return $node;

  };

# ---   *   ---   *   ---

  $out=$group;

FAIL:
  return $out;

};

# ---   *   ---   *   ---

sub walkup($self,$top=undef) {

  # opt defaults
  $top//=-1;

# ---   *   ---   *   ---

  my $node=$self->{parent};
  my $i=0;

  while($top<$i) {
    my $par=$node->{parent};
    if($par) {
      $node=$par;

    } else {last};$i++;
  };

  return $node;

};

# ---   *   ---   *   ---

sub shiftlv($self,$pos,$sz) {

  state $BLANKS_RE=qr{

    ^\$\:BLANK\;\>$

  }x;

  my $frame=$self->{frame};

# ---   *   ---   *   ---

  for my $i(0..$sz-1) {
    $frame->nit($self,'$:BLANK;>');

  };

  my $end=@{$self->{leaves}}-1;
  for my $i(reverse ($pos..$end)) {

    my $x=$self->{leaves}->[$i];

    $self->{leaves}->[$i]
      =$self->{leaves}->[$i-1];

    $self->{leaves}->[$i-1]=$x;

  };

# ---   *   ---   *   ---

  $self->pluck(
    $self->branches_in($BLANKS_RE)

  );

  $self->cllv();
  return;

};

# ---   *   ---   *   ---
# puts new nodes anywhere on the tree

sub insert($self,$pos,@list) {

  my @ar=@{$self->{leaves}};

  my @head=();
  my @tail=();

# ---   *   ---   *   ---
# cut array at position

  if($pos) {
    @head=@ar[0..$pos-1]

  };

  if($pos<=$#ar) {
    @tail=@ar[$pos..$#ar];

  };

# ---   *   ---   *   ---
# insert new elements

  my @insert=map
    {$self->{frame}->nit($self,$ARG)} @list;

  my @leaves=(@head,@insert,@tail);

# ---   *   ---   *   ---
# overwrite

  $self->{leaves}=\@leaves;
  $self->idextrav();

  return;

};

# ---   *   ---   *   ---
# in:overwrite,node arr
# push node array to leaves

sub pushlv($self,$overwrite,@pending) {

  if($overwrite) {
    $self->{leaves}=[];

  };

# ---   *   ---   *   ---

  # move nodes
  my %cl=();
  while(@pending) {

    my $node=shift @pending;

    my $par=$node->{parent};

    $node->{parent}=$self;

# ---   *   ---   *   ---

    push @{ $self->{leaves} },$node;

    if($par && $par!=$node->{parent}) {
      $par->pluck($node);
      $cl{$par}=$par;

    };

  };

# ---   *   ---   *   ---

  for my $node(keys %cl) {
    $node=$cl{$node};
    $node->cllv();

  };

  $self->cllv();

  return;

};

# ---   *   ---   *   ---
# discard blank nodes

sub cllv($self) {

  my @cpy=();
  my @leaves=@{$self->{leaves}};

  for my $i(0..$#leaves) {

    # push only nodes that arent plucked
    my $node=$self->{leaves}->[$i];
    if(defined $node) {
      push @cpy,$node;

    };

  # overwrite with filtered array
  };

  $self->{leaves}=\@cpy;
  $self->idextrav();

  return;

};

# ---   *   ---   *   ---

# in:self,string
# branch out node from whitespace split

sub tokenize($self,$exp) {

  my $frame=$self->{frame};
  my $lang=$frame->{master}->{lang};

  # patterns
  my $ops=$lang->{ops};
  my $del_op=$lang->{del_ops};
  my $ndel_op=$lang->{ndel_ops};

  my $ode=$lang->{ode};
  my $cde=$lang->{cde};
  my $pesc=$lang->{pesc};

# ---   *   ---   *   ---
# spaces are meaningless

  my @elems=();

  my @ar=split m/([^\s]*)\s+/,$exp;
  my $i=0;

# ---   *   ---   *   ---

  while(@ar) {
    my $elem=shift @ar;

    if(defined $elem && length $elem) {
      my $node=$frame->nit($self,"field_$i");

# ---   *   ---   *   ---

      for my $tok(
        split m/$ops|$del_op/,
        $elem

      ) {

        if(defined $tok && length $tok) {
          $frame->nit($node,$tok);

        };
      };

      $i++;

# ---   *   ---   *   ---

    };
  };

# ---   *   ---   *   ---
# classify tokens

  for my $leaf(@{$self->{leaves}}) {

    $leaf->{value_type}
      =$lang->classify($leaf->{value});

  };

  return;

};

# ---   *   ---   *   ---

sub tokenize2($self) {

  my $body=$self->{value};
  my $lang=$self->{frame}->{master}->{lang};

  my $cut_token_re=$shwl::CUT_RE;
  my $keyword=$lang->{keyword_re};

  my $name=$lang->{names};
  my $num=$lang->{nums_re};
  my $vstr=$lang->{vstr};
  my $hier_re=$lang->{hier_re};

  my $op=$lang->{ops};

  my $scope_bound=$lang->{scope_bound};

  my $label=qr{

    [_\w][_\w\d]*:
    (?! :|__\w{1,20}_CUT_\d{1,4}__:)

  }x;

# ---   *   ---   *   ---

  my $token_re=qr{^

    (?:$cut_token_re)
  | (?:$keyword)
  | (?:$label)

  | (?:$op)

  | (?:$vstr)
  | (?:$hier_re)
  | (?:$name)

  | (?:$num)
  | (?:$scope_bound)

  | (?:.*)

  }x;

# ---   *   ---   *   ---

  my $ws_re=qr{^[\s\n]*|[\s\n]*$};

  $body=~ s/$ws_re//sg;

  my @elems=();

  while($body=~s/($token_re)//sxm

  ) {

    my $elem=${^CAPTURE[0]};
    $body=~ s/$ws_re//sg;

    if(!defined $elem
    || !length lang::stripline($elem)

    ) {last};

    push @elems,$elem;

  };

# ---   *   ---   *   ---

  if(@elems) {
    $self->{value}=shift @elems;
    for my $elem(@elems) {
      $self->{frame}->nit($self,$elem);

    };

  };

};

# ---   *   ---   *   ---
# clump fields of arguments together

sub agroup($self) {

  my $frame=$self->{frame};
  my $lang=$frame->{master}->{lang};

  my @shifts=();
  my $i=0;

# ---   *   ---   *   ---

  my @anchors=();
  my @trash=();

  $self->cllv();

  my @leaves=@{$self->{leaves}};
  TOP:my $leaf=shift @leaves;

  if($leaf->{value} eq q{,}) {
    push @trash,$leaf;
    pop @anchors;

  };

# ---   *   ---   *   ---

  if($anchors[-1]) {

    my $anchor=$anchors[-1]->[0];
    my $argc=\$anchors[-1]->[1];

    $frame->nit($anchor,$leaf->{value});
    push @trash,$leaf;

    $$argc--;

    if(!$$argc) {
      pop @anchors;

    };

  };

# ---   *   ---   *   ---

  $leaf->cllv();
  unshift @leaves,@{$leaf->{leaves}};

  if(@leaves) {goto TOP};
  TAIL:$self->pluck(@trash);

  $self->delimchk();
  return;

# ---   *   ---   *   ---
# expands the tree to solve expressions

};sub subdiv($self) {

  my $frame=$self->{frame};
  my $lang=$frame->{master}->{lang};

  my $ndel_op=$lang->{ops};
  my $del_op=$lang->{del_ops};

  my $cde=$lang->{cde};

  my %matched=();

  my $root=$self;
  my @leaves=();

# ---   *   ---   *   ---
# iter tree until operator found
# then restart the loop (!!!)

  TOP:

  $root->cllv();

  my $high_prio=9999;
  my $high_i=0;

  my @pending=();

  my @ar=@{$root->{leaves}};
  for my $leaf(@ar) {

    if($matched{"$leaf"}) {next};

    my $i=$leaf->{idex};

    my $prev=($i>0) ? $ar[$i-1] : undef;
    my $next=($i<$#ar) ? $ar[$i+1] : undef;

    if(@{$leaf->{leaves}}) {
      push @leaves,$leaf;

    };

# ---   *   ---   *   ---
# check found operands

    my @move=();
    my ($j,$k)=(0,1);

    # node is operator
    if(exists $lang->{op_prec}->{$leaf->{value}}) {

      # look at previous and next node
      for my $n($prev,$next) {
        if(!defined $n) {$k++;next;};

        # n is an operator with leaves
        # or n is not an operator
        my $valid=(
            ($n->{value}=~ m/$ndel_op|$del_op/)
         && @{$n->{leaves}}

        )!=0;$valid|=!($n->{value}=~
          m/$del_op|$ndel_op/

        );

# ---   *   ---   *   ---

        if($valid) {

          #if($n=~ m/$cde/) {$n=$n->{parent};};

          $j|=$k;
          push @move,$n;

        };$k++;

      };

# ---   *   ---   *   ---

    };if(@move) {

      my $prio

        =$lang->{op_prec}
        ->{$leaf->{value}}
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

    $leaf->{value}=bless {

      op=>$leaf->{value},
      idex=>$idex,

    },'node_op';

    $matched{"$leaf"}=1;
    $leaf->pushlv(0,$root->pluck(@move));
    goto TOP;

# ---   *   ---   *   ---

  };if(@leaves) {

    $root=shift @leaves;
    goto TOP;

  };

  return;

# ---   *   ---   *   ---
# solves operations across the hierarchy

};sub collapse($self,%opt) {

  my $root=$self;
  my $depth=0;

  my $max_depth=$opt{depth};
  my $only_if=$opt{only};
  my $no_numcon=$opt{no_numcon};

  my $lang=$self->{frame}->{master}->{lang};
  my $op_prec=$lang->{op_prec};
  my $del_op=$lang->{del_ops};
  my $ode=$lang->{ode};

  my @leaves=($self);
  my @solve=();

# ---   *   ---   *   ---
# collect pending operations

  while(@leaves) {

    $self=shift @leaves;
    if($self == 0) {$depth--;next}
    elsif($self == 1) {$depth++;next};

    if(defined $max_depth
    && $depth>=$max_depth) {next};

    if($self->{value}=~ m/^$OPERATOR$/) {

      if(

         defined $only_if
      && !($self->{value}->{op}=~ m/^$only_if/)

      ) {goto SKIP};

      push @solve,$self;

    };SKIP:
    unshift @leaves,1,@{$self->{leaves}},0;

  };

# ---   *   ---   *   ---
# handle operations bottom to top
# i.e. first in last out

  while(@solve) {

    my $self=pop @solve;

    my $op=$op_prec->{$self->{value}->{op}};
    my $idex=$self->{value}->{idex};

# ---   *   ---   *   ---
# argument conversions
# TODO: type-checks!

    my @args=$self->pluck(@{$self->{leaves}});
    for my $arg(@args) {

      if(!$opt{no_numcon}) {

      for my $key(keys %{$lang->nums}) {
        $lang->numcon(\$arg->{value});

      }};$arg=\$arg->{value};

    };
# ---   *   ---   *   ---

    $self->{value}=$op->[$idex]->[1]->(@args);

    if(

      (defined $self->{parent}->{value}) &&
      $self->{parent}->{value}=~ m/^${ode}$/

    ) {

      if($self->{parent} eq $root) {
        $root=$self;

      };

      $self->{parent}->repl($self);

    };

# ---   *   ---   *   ---

  };

  return $root;

};

# ---   *   ---   *   ---
# replaces field_N with it's children

sub defield($self) {
  Readonly state $re=>qr{^field_\d+$};
  my @ar=$self->branches_in($re);
  map {$_->flatten_branch()} @ar;

  return;

};

# ---   *   ---   *   ---
# check for ([]) delimiters

sub delimchk($self) {

  my $frame=$self->{frame};
  my $lang=$frame->{master}->{lang};

  my $ode=$lang->{ode};
  my $cde=$lang->{cde};

  my @leaves=($self);
  TOP:$self=shift @leaves;

# ---   *   ---   *   ---

  my $i=0;
  for my $leaf(@{$self->{leaves}}) {
    if(!defined $leaf) {last};

    if($leaf->{value}=~ $ode) {
      $leaf->delimbrk($i);

    };$i++;

  };

# ---   *   ---   *   ---

  unshift @leaves,@{$self->{leaves}};
  if(@leaves) {goto TOP};

  return;

# ---   *   ---   *   ---
# makes a node hierarchy from a
# delimiter-[values]-delimiter sequence

};sub delimbrk($self,$i) {

  my $frame=$self->{frame};
  my $lang=$frame->{master}->{lang};

  my @anchors=();
  my @moved=();

  my $ode=$lang->{ode};
  my $cde=$lang->{cde};

  my @ar=@{$self->{parent}->{leaves}};
  @ar=@ar[$i..$#ar];

# ---   *   ---   *   ---

  for my $leaf(@ar) {

    if($anchors[-1]) {
      push @{$moved[-1]},$leaf;

    };

# ---   *   ---   *   ---

    if($leaf->{value}=~ $ode) {
      push @anchors,$leaf;
      push @moved,[];

# ---   *   ---   *   ---

    } elsif(

         ($leaf->{value}=~ $cde)
      && @anchors

      ) {

      my $anchor=pop @anchors;
      my $ref=pop @moved;

      $self->pluck(@$ref);
      $anchor->pushlv(0,@$ref);

    };

# ---   *   ---   *   ---

  };

  return;

};

# ---   *   ---   *   ---
# in: node to replace self by
# replaces a node in the hierarchy

sub repl($self,$other) {

  my $ref=$self->{parent}->{leaves};
  my $i=-1;

# ---   *   ---   *   ---

  for my $node(@$ref) {

    $i++;
    if($node eq $self) {
      last;

    };
  };

# ---   *   ---   *   ---

  if($i>=0) {
    $other->{parent}=$self->{parent};
    $ref->[$i]=$other;

    $self->{parent}->cllv();

  };

  return;

};

# ---   *   ---   *   ---
# replaces node with it's leaves

sub flatten_branch($self,%args) {

  # opt defaults
  $args{keep_root}//=0;

  my @move=$self->pluck(@{$self->{leaves}});
  my $par=$self->{parent};

  $par->idextrav();

# ---   *   ---   *   ---

  my $idex=$self->{idex};
  my @ar=@{$par->{leaves}};

  if($args{keep_root}) {unshift @move,$self};
  if($idex) {unshift @move,@ar[0..$idex-1]};
  if($idex<$#ar) {push @move,@ar[$idex+1..$#ar]};

# ---   *   ---   *   ---

  $par->pushlv(1,@move);
  $par->cllv();

  return;

};

# ---   *   ---   *   ---
# in: node list
# removes leaves from node

sub pluck($self,@pending) {

  # return value
  my @plucked=();

# ---   *   ---   *   ---
# match nodes in list

  { my $i=0;

  for my $leaf(@{$self->{leaves}}) {

    # skip removed nodes
    if(!$leaf) {next;};

    # iter node array
    my $j=0;
    for my $node(@pending) {

      # skip already removed ones
      if(!$node) {$j++;next};

# ---   *   ---   *   ---

      # node is in remove list
      if($leaf eq $node) {

        # save the removed nodes
        push @plucked,$self->{leaves}->[$i];

        # remove from list and leaves
        $pending[$j]=undef;
        $self->{leaves}->[$i]=undef;

        # go to next leaf
        last;

      };$j++; # next in remove list
    };$i++; # next in leaves

  }};

# ---   *   ---   *   ---

  # discard blanks
  $self->cllv();

  # return removed nodes
  return @plucked;

};

# ---   *   ---   *   ---

sub idextrav($self) {

#  my @pending=($self);
#  while(@pending) {
#
#    $self=shift @pending;

    my $i=0;
    for my $child(@{$self->{leaves}}) {
      $child->{idex}=$i++;

    };

#    unshift @pending,@{$self->{leaves}};
#
#  };

  return;

};

# ---   *   ---   *   ---
# fetches names from ext module
# replaces these names with ptr references

sub findptrs($self) {

  my $frame=$self->{frame};
  my $lang=$frame->{master}->{lang};

  my $fr_ptr=$frame->{master}->{ptr};

  my $pesc=$lang->{pesc};
  my $types=$lang->{types};

# ---   *   ---   *   ---
# iter leaves

  my @leaves=($self);
  while(@leaves) {

    $self=shift @leaves;
    unshift @leaves,@{$self->{leaves}};

    # skip $:escaped;>
    if($self->{value}=~ $pesc) {
      next;

    };

# ---   *   ---   *   ---
# solve/fetch non-numeric values

    if($lang->valid_name(
        $self->{value}

      ) && !(exists $types->{$self->{value}})

    ) {

      $self->{value}=$fr_ptr->fetch($self->{value});

    };

# ---   *   ---   *   ---

  };

  return;

};

# ---   *   ---   *   ---

sub hashtree($h) {

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

  return $frame->{trees}->[-1]->{root};

};

# ---   *   ---   *   ---
# does/undoes ode to op conversion

sub odeop($self,$set) {

  my @leaves=($self);

  my $lang=$self->{frame}->{master}->{lang};
  my $ode=$lang->{ode};

# ---   *   ---   *   ---

  while(@leaves) {

    $self=shift @leaves;
    unshift @leaves,@{$self->{leaves}};

    if($set && $self->{value}=~ m/^$ode$/) {
      $self->{value}=bless {
        op=>$1,
        idex=>-1,

      },'node_op';

# ---   *   ---   *   ---

    } elsif((!$set)

      && ($self->{value}=~ $OPERATOR)
      && ($self->{value}->{op}=~ m/^$ode$/)

    ) {

      $self->{value}=$self->{value}->{op};

    };

# ---   *   ---   *   ---

  };

  return;

};

# ---   *   ---   *   ---
# saves nodes whose values are references

sub branchrefs($self,$dst) {

  my $lang=$self->{frame}->{master}->{lang};
  my $ode=$lang->{ode};

  my @leaves=($self);

# ---   *   ---   *   ---
# walk the hierarchy

  while(@leaves) {

    $self=shift @leaves;
    unshift @leaves,@{$self->{leaves}};

# ---   *   ---   *   ---
# use stringified ref as key into value

    if(

        (length ref $self->{value})
    && !(exists $dst->{$self->{value}})

    ) {$dst->{$self->{value}}=$self;};

# ---   *   ---   *   ---

  };

  return;

};

# ---   *   ---   *   ---
# gives list of leaves in tree that
# dont have leaves of their own

sub leafless($self,%opt) {

  my @leaves=($self);
  my @result=();

# ---   *   ---   *   ---
# walk the hierarchy

  while(@leaves) {

    $self=shift @leaves;
    if(!@{$self->{leaves}}) {
      push @result,$self;

    } else {
      unshift @leaves,@{$self->{leaves}};

    };

  };

# ---   *   ---   *   ---
# optionally return a specific element
# else whole array is given

  my $out=\@result;
  if(defined $opt{i}) {
    $out=$result[$opt{i}];

  };

  return $out;

};

# ---   *   ---   *   ---
# gives list of branches holding value

sub branches_with($self,$lookfor) {

  my $anchor=$self;

  my @leaves=();
  my @found=();

# ---   *   ---   *   ---
# iter leaves

TOP:

  if(!@{$anchor->{leaves}}) {goto SKIP};

  for my $leaf(@{$anchor->{leaves}}) {

    # accept branch if value found in leaves
    if($leaf->{value}=~ $lookfor) {
      push @found,$anchor;
      last;

    };
  };

  unshift @leaves,@{$anchor->{leaves}};

# ---   *   ---   *   ---
# continue if children pending

SKIP:

  if(@leaves) {

    $anchor=shift @leaves;
    goto TOP;

  };

# ---   *   ---   *   ---
# return matches

TAIL:
  return @found;

};

# ---   *   ---   *   ---
# gives list of branches starting with value

sub branches_in($self,$lookfor) {

  my @leaves=($self);
  my @found=();

# ---   *   ---   *   ---
# look for matches recursively

  while(@leaves) {

    $self=shift @leaves;
    if($self->{value}=~ $lookfor) {
      push @found,$self;

    };

    unshift @leaves,@{$self->{leaves}};

# ---   *   ---   *   ---
# return matching nodes

  };return @found;

};

# ---   *   ---   *   ---
# gives list of branches holding value

sub branch_with($self,$lookfor) {

  my $anchor=$self;

  my @leaves=();
  my $found=undef;

# ---   *   ---   *   ---
# iter leaves

  while(@leaves) {

    my $anchor=shift @leaves;
    if(!@{$anchor->{leaves}}) {next};

    for my $leaf(@{$anchor->{leaves}}) {

      # accept branch if value found in leaves
      if($leaf->{value}=~ $lookfor) {
        $found=$anchor;
        last;

      };
    };

# ---   *   ---   *   ---

    if(!defined $found) {
      unshift @leaves,@{$anchor->{leaves}};

    } else {
      last;

    };

# ---   *   ---   *   ---
# return matches

  };

TAIL:
  return $found;

};

# ---   *   ---   *   ---
# gives list of branches starting with value

sub branch_in($self,$lookfor) {

  my @leaves=($self);
  my $found=undef;

# ---   *   ---   *   ---
# look for matches recursively

  while(@leaves) {

    $self=shift @leaves;
    if($self->{value}=~ $lookfor) {
      $found=$self;
      last;

    };

    unshift @leaves,@{$self->{leaves}};


# ---   *   ---   *   ---
# return matching nodes

  };return $found;

};

# ---   *   ---   *   ---
# gives array of values from node array

sub plain_arr(@tree) {

  my @result=();
  for my $branch(@tree) {

    for my $leaf(@{$branch->{leaves}}) {
      push @result,$leaf->{value};

    };
  };

  return @result;

# ---   *   ---   *   ---
# ^ same, includes root nodes

};sub plain_arr2(@tree) {

  my @result=();
  for my $branch(@tree) {

    push @result,$branch->{value};
    for my $leaf(@{$branch->{leaves}}) {
      push @result,$leaf->{value};

    };
  };

  return @result;

};

# ---   *   ---   *   ---

sub branch_values($self,$pat) {

  my @ar=$self->branches_in($pat);
  @ar=plain_arr(@ar);

  return @ar;

};

sub leaf_value($self,$idex) {
  return $self->{leaves}->[$idex]->{value};

};

# ---   *   ---   *   ---

sub nocslist($self) {

  my @leaves=($self);
  my @pending=();

  my $sep=$self->{frame}->{master}
    ->{lang}->{separators};

# ---   *   ---   *   ---

  while(@leaves) {
    $self=shift @leaves;
    unshift @leaves,@{$self->{leaves}};

    if(

       $self->{value}=~ m/node_op/
    && $self->{value}->{op}=~ m/${sep}/

    ) {push @pending,$self;};

  };

# ---   *   ---   *   ---

  map {$_->collapse(
    only=>$sep,
    no_numcon=>1

  );} @pending;

  return;

};

# ---   *   ---   *   ---

sub flatten($self,%args) {

  # args defaults
  $args{max_depth}//=0x24;
  $args{keep_root}//=0;

  my $max_depth=$args{max_depth};

# ---   *   ---   *   ---
# handle walk array

  my @leaves=();
  if($args{keep_root}) {
    push @leaves,$self;

  } else {
    push @leaves,@{$self->{leaves}};

  };

# ---   *   ---   *   ---

  my $depth=0;
  my $s=$NULLSTR;

# ---   *   ---   *   ---

  while(@leaves) {

    $self=shift @leaves;
    if($self == 0) {$depth--;next}
    elsif($self == 1) {$depth++;next};

    $s.=$self->{value}.q{ };
    if($depth>=$max_depth) {
      next;

    };

    unshift @leaves,1,@{$self->{leaves}},0;

  };

  return $s;

};

# ---   *   ---   *   ---

sub exp_arr($self) {

  my @leaves=($self);
  my @exps=();

# ---   *   ---   *   ---

  while(@leaves) {
    $self=shift @leaves;

    if($self->{has_eb}) {
      push @exps,$self;

    };

    unshift @leaves,@{$self->{leaves}};

  };

  return @exps;

};

# ---   *   ---   *   ---
# print node leaves

sub prich($self,%args) {

  # opt defaults
  $args{errout}//=0;
  $args{max_depth}//=0x24;

  my $errout=$args{errout};
  my $prev_depth=0;

  my $root=$self;
  my @leaves=($self);

  my $mess=$NULLSTR;

# ---   *   ---   *   ---

  my $FH=($errout)
    ? *STDERR
    : *STDOUT
    ;

# ---   *   ---   *   ---

  while(@leaves) {

    $self=shift @leaves;

    my $depth=0;
    if(!$depth && $self ne $root) {

      my $par=$self->{parent};

# ---   *   ---   *   ---

      while(defined $par) {

        $depth++;
        if($par eq $root) {last};

        $par=$par->{parent};

      };

    };

# ---   *   ---   *   ---

    my $branch=($depth)
      ? '.  'x($depth-1).'\-->'
      : $NULLSTR
      ;

    if($depth<$prev_depth) {
      $branch=$NULLSTR.

        (('.  'x($depth)."\n")x2).
        $branch;

    }$prev_depth=$depth;

# ---   *   ---   *   ---
# check value is an operator (node_op 'class')

    my $v=(

       ($self->{value}=~ $OPERATOR)
    && length ref $self->{value}

    ) ? $self->{value}->{op}
      : $self->{value}
      ;

# ---   *   ---   *   ---
# this is only here so i can debug plps trees!

    $v=(

       $self->{value}=~ m/^plps_obj/
    && length ref $self->{value}

    ) ? $self->{value}->{name}
      : $v
      ;

# ---   *   ---   *   ---

    $mess.=$branch.$v."\n";
    if($depth < $args{max_depth}) {
      unshift @leaves,@{$self->{leaves}};

    };

  };

  return print {$FH} "$mess\n";

};

# ---   *   ---   *   ---

package peso::node::frame;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# constructors

sub nit($frame,@args) {
  return peso::node::nit($frame,@args);

};sub create($master) {

  my $frame=bless {

    trees=>[],
    master=>$master,

  },'peso::node::frame';

  return $frame;

};

# ---   *   ---   *   ---
1; # ret
