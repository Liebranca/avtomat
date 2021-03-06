#!/usr/bin/perl
# ---   *   ---   *   ---
# TREE
# Natural hierarchies
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Tree;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;
  use Chk;

  use Frame;

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use Shwl;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---

sub valid($self) {
  return Arstd::valid($self);

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
# constructors

sub new_frame($class) {

  return Frame::new(
    roots=>{},
    class=>$class

  );

};

# ---   *   ---   *   ---

sub from_hashref($frame,$h) {

  my $root=undef;
  my $self=undef;

  my @pending=($self,$h);

# ---   *   ---   *   ---

  while(@pending) {

    ($self,$h)=@{(shift @pending)};

    for my $key(keys %$h) {

      my $value=$h->{$key};
      my $node=$frame->nit($self,$key);

      $root//=$self;

      if(is_hashref($value)) {
        push @pending,([$node,$value]);

      };

    };

  };

  return $self;

};

# ---   *   ---   *   ---
# make child node or create a new tree

sub nit($class,$frame,$parent,$val,%O) {

  # opt defaults
  $O{unshift_leaves}//=0;

# ---   *   ---   *   ---

  # make node instance
  my $node=bless {

    value=>$val,
    value_type=>0x00,

    leaves=>[],
    parent=>undef,
    idex=>0,

    frame=>$frame,

  },$class;

# ---   *   ---   *   ---
# add leaf if ancestry

  if(defined $parent) {

    if($O{unshift_leaves}) {
      unshift @{$parent->{leaves}},$node;

    } else {
      push @{$parent->{leaves}},$node;

    };

    $node->{parent}=$parent;
    $parent->idextrav();

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
# ascends the hierarchy n times

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

    } else {last};

    $i++;

  };

  return $node;

};

# ---   *   ---   *   ---
# push node array to leaves

sub pushlv($self,@pending) {

  while(@pending) {

    my $node=shift @pending;
    my $par=$node->{parent};

    $node->{parent}=$self;

    push @{ $self->{leaves} },$node;

    if($par && $par!=$node->{parent}) {
      $par->pluck($node);

    };

  };

  $self->idextrav();
  return;

};

# ---   *   ---   *   ---
# discard blank nodes

sub cllv($self) {

  my @clean=();

  for my $node(@{$self->{leaves}}) {
    push @clean,$node if defined $node;

  };

  $self->{leaves}=\@clean;
  $self->idextrav();

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

  $par->pushlv(@move,overwrite=>1);
  $par->cllv();

  return;

};

# ---   *   ---   *   ---
# removes leaves from node

sub pluck($self,@pending) {

  my @plucked=();

  for my $leaf(@{$self->{leaves}}) {

    if(grep {$leaf eq $ARG} @pending) {
      push @plucked,$leaf;
      $leaf=undef;

    };

  };

  $self->cllv();
  return @plucked;

};

# ---   *   ---   *   ---
# resets indices in branch

sub idextrav($self) {

  my $i=0;
  for my $child(@{$self->{leaves}}) {
    $child->{idex}=$i++;

  };

  return $i;

};

# ---   *   ---   *   ---
# gets 'absolute' idex of leaf node
# ie: nth node pushed to branch

sub absidex($self,$leaf) {

  my $i=0;
  my $root=$self->{parent};

  for my $branch(@{$root->{leaves}}) {

    last if $branch eq $self;
    $i+=int(@{$branch->{leaves}});

  };

  $self->idextrav();
  $i+=$leaf->{idex};

  return $i;

};

# ---   *   ---   *   ---
# gives list of leaves in tree that
# dont have leaves of their own

sub leafless($self,%O) {

  # defaults
  $O{i}//=undef;
  $O{give_parent}//=0;

  my @leaves=($self);
  my @result=();

# ---   *   ---   *   ---
# walk the hierarchy

  while(@leaves) {

    $self=shift @leaves;
    if(!@{$self->{leaves}}) {

      if($O{give_parent}) {

        my $par=$self->{parent};

        push @result,$par
        if defined $par
        && !(grep {$par eq $ARG} @result);

        next;

      } else {
        push @result,$self;

      };

    } else {
      unshift @leaves,@{$self->{leaves}};

    };

  };

# ---   *   ---   *   ---
# optionally return a specific element
# else whole array is given

  my $out=\@result;
  if(defined $O{i}) {
    $out=$result[$O{i}];

  };

  return $out;

};

# ---   *   ---   *   ---
# saves nodes whose values are references

sub branchrefs($self,$dst) {

  my @leaves=($self);

  while(@leaves) {

    $self=shift @leaves;
    unshift @leaves,@{$self->{leaves}};

    # use stringified ref as key into value
    if( (length ref $self->{value})
    && !(exists $dst->{$self->{value}})

    ) {$dst->{$self->{value}}=$self};

  };

  return;

};

# ---   *   ---   *   ---
# gives list of branches holding value

sub branches_with($self,$lookfor,%O) {

  # defaults
  $O{keep_root}//=1;
  $O{max_depth}//=0x24;
  $O{first_match}//=0;

# ---   *   ---   *   ---

  my @found=();
  my @leaves=();

  my $depth=0;
  if($O{keep_root}) {
    push @leaves,$self;

  } else {
    push @leaves,@{$self->{leaves}};

  };

# ---   *   ---   *   ---
# look for matches recursively

  while(@leaves) {

    $self=shift @leaves;
    if($self eq 0) {$depth--;next}
    elsif($self eq 1) {$depth++;next};

# ---   *   ---   *   ---
# only accept matches *within* a branch

    for my $leaf(@{$self->{leaves}}) {

      if($leaf->{value}=~ $lookfor) {
        push @found,$self;
        last;

      };

    };

    last if $O{first_match} && @found;

    if($depth>=$O{max_depth}) {next};
    unshift @leaves,1,@{$self->{leaves}},0;

# ---   *   ---   *   ---
# return matches

  };

  return @found;

};

# ---   *   ---   *   ---
# gives list of branches starting with value

sub branches_in($self,$lookfor,%O) {

  # defaults
  $O{keep_root}//=1;
  $O{max_depth}//=0x24;
  $O{first_match}//=0;

# ---   *   ---   *   ---

  my @leaves=();
  my @found=();

  my $depth=0;
  if($O{keep_root}) {
    push @leaves,$self;

  } else {
    push @leaves,@{$self->{leaves}};

  };

# ---   *   ---   *   ---
# look for matches recursively

  while(@leaves) {

    $self=shift @leaves;
    if($self eq 0) {$depth--;next}
    elsif($self eq 1) {$depth++;next};

# ---   *   ---   *   ---
# accept all matches ;>

    if($self->{value}=~ $lookfor) {
      push @found,$self;
      last if $O{first_match};

    };

    if($depth>=$O{max_depth}) {next};
    unshift @leaves,1,@{$self->{leaves}},0;

# ---   *   ---   *   ---
# return matches

  };

  return @found;

};

# ---   *   ---   *   ---
# ^shorthands

sub branch_with($self,$lookfor,%O) {

  $O{first_match}=1;
  return ($self->branches_with($lookfor,%O))[0];

};

sub branch_in($self,$lookfor,%O) {

  $O{first_match}=1;
  return ($self->branches_in($lookfor,%O))[0];

};

# ---   *   ---   *   ---

sub branch_values($self) {
  return map {$ARG->{value}} @{$self->{leaves}};

};

sub leaf_value($self,$idex) {
  return $self->{leaves}->[$idex]->{value};

};

# ---   *   ---   *   ---
# flattens tree and stringifies it

sub to_string($self,%O) {

  # args defaults
  $O{max_depth}//=0x24;
  $O{keep_root}//=0;

# ---   *   ---   *   ---
# handle walk array

  my @leaves=();
  if($O{keep_root}) {
    push @leaves,$self;

  } else {
    push @leaves,@{$self->{leaves}};

  };

# ---   *   ---   *   ---
# recurse and cat to string

  my $depth=0;
  my $s=$NULLSTR;

  while(@leaves) {

    $self=shift @leaves;
    if($self == 0) {$depth--;next}
    elsif($self == 1) {$depth++;next};

    $s.=$self->{value}.q{ };

    if($depth>=$O{max_depth}) {next};
    unshift @leaves,1,@{$self->{leaves}},0;

  };

  return $s;

};

# ---   *   ---   *   ---
# print node leaves

sub prich($self,%O) {

  # opt defaults
  $O{errout}//=0;
  $O{max_depth}//=0x24;

  my $prev_depth=0;

  my $root=$self;
  my @leaves=($self);

  my $mess=$NULLSTR;

# ---   *   ---   *   ---

  while(@leaves) {

    $self=shift @leaves;

    my $depth=0;
    if(!$depth && $self ne $root) {

      my $par=$self->{parent};

# ---   *   ---   *   ---

      while(defined $par) {

        $depth++;

        last if($par eq $root);
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

    };

    $prev_depth=$depth;

# ---   *   ---   *   ---
# check value is an operator (node_op 'class')

    my $v=$self->{value};
    $mess.=$branch."$v\n";

    next if($depth>=$O{max_depth});
    unshift @leaves,@{$self->{leaves}};

  };

# ---   *   ---   *   ---
# select filehandle

  my $FH=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  return print {$FH} "$mess\n";

};

# ---   *   ---   *   ---
1; # ret
