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

  use Carp;
  use Readonly;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.03.4;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    uid       => 0x00,

    -roots    => {},
    -autoload => [qw(from_list)],

  }};

# ---   *   ---   *   ---
# importer injection

St::imping {

  '*DESTROY' => sub ($dst,$ice) {

    $ice->discard()
    if defined $ice->{value};

  },

};

# ---   *   ---   *   ---
# makes copy of instance

sub dup($self,$root=undef) {


  # get ctx
  my $frame=$self->{frame};
  my @leaves=();


  # make copy of own
  my $copy=$frame->new($root,$self->{value});

  # ^recurse for each child
  for my $leaf(@{$self->{leaves}}) {
    $leaf->dup($copy);

  };


  return $copy;

};

# ---   *   ---   *   ---
# ^copies custom attrs

sub dupa($self,$root,@attr) {


  # get ctx
  my $frame  = $self->{frame};
  my @leaves = ();


  # make copy of own
  my $copy=$frame->new($root,$self->{value});

  # ^write custom attrs attrs
  map  {$copy->{$ARG}=$self->{$ARG}} @attr;


  # recurse for each child
  for my $leaf(@{$self->{leaves}}) {
    $leaf->dupa($copy,@attr);

  };


  return $copy;

};

# ---   *   ---   *   ---
# cstruc from hash

sub from_hashref($frame,$h) {

  my $root=undef;
  my $self=undef;

  my @pending=($self,$h);


  while(@pending) {

    ($self,$h)=@{(shift @pending)};

    for my $key(keys %$h) {

      my $value=$h->{$key};
      my $node=$frame->new($self,$key);

      $root//=$self;

      if(is_hashref($value)) {
        push @pending,([$node,$value]);

      };

    };

  };

  return $self;

};

# ---   *   ---   *   ---
# cstruc from a list

sub from_list($class,$frame,@src) {


  # first element is first node
  my $root=shift @src;
     $root=$frame->new(undef,$root);

  # ^cat to it
  my $anchor = [$root];
  my $prev   = $root;


  # the rest of the elements are
  # leaf nodes!
  while(@src) {


    # go up one level on undef
    my $leaf=shift @src;

    if(! defined $leaf) {
      pop @$anchor;
      next;


    # go down one level on array
    } elsif(is_arrayref $leaf) {
      push    @$anchor,$prev;
      unshift @src,@$leaf,undef;


    # make node at current level on value
    } else {
      $prev=$anchor->[-1]->inew($leaf);

    };


  };


  return $root;

};

# ---   *   ---   *   ---
# make child node or make a new tree

sub new($class,$frame,$parent,$val,%O) {

  # opt defaults
  $O{unshift_leaves}//=0;

  # make node instance
  my $node=bless {

    value      => $val,
    value_type => 0x00,

    leaves     => [],
    parent     => undef,
    idex       => 0,

    frame      => $frame,
    fcache     => {},

    plucked    => 0,
    '*fetch'   => undef,

    -skipio    => 0,
    -uid       => $frame->{uid}++,

  },$class;

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
# ^from instance

sub inew($self,@args) {

  return $self->{frame}->new(
    $self,@args

  );

};

# ---   *   ---   *   ---
# force hierarchy to exist
# give last node

sub force_get($self,@path) {

  my $out=$self->fetch(
    path     => \@path,
    existing => 0,

  );

  # ensure fvalue
  $out->inew($NULL)
  if ! @{$out->{leaves}};

  # ^give ref
  return $out->fvalue();

};

# ---   *   ---   *   ---
# ^only existing

sub get($self,@path) {

  my $out=$self->fetch(
    path  => \@path,
    throw => 1,

  );

  $out=(! $out->{leaves}->[0])
    ? throw_bad_fetch(@path,'[value]')
    : $out
    ;

  return $out->fvalue();

};

# ---   *   ---   *   ---
# force_get + assignment

sub force_set($self,$value,@path) {

  my $vref  = $self->force_get(@path);
     $$vref = $value;

  return $vref;

};

# ---   *   ---   *   ---
# ^only existing

sub set($self,$value,@path) {

  my $vref  = $self->get(@path);
     $$vref = $value;

  return $vref;

};

# ---   *   ---   *   ---
# existance check

sub has($self,@path) {

  my $out=$self->fetch(
    path  => \@path,
    throw => 0,

  );

  $out=($out && $out->{leaves}->[0])
    ? $out->fvalue()
    : undef
    ;

  return $out;

};

# ---   *   ---   *   ---
# ^get leaf in scope

sub haslv($self,@path) {

  return $self->fetch(
    path  => \@path,
    throw => 0,

  );

};

# ---   *   ---   *   ---
# ^guts of all

sub fetch($self,%O) {

  # defaults
  $O{existing}  //= 1;
  $O{throw}     //= 0;
  $O{max_depth} //= 0;
  $O{keep_root} //= 0;

  $O{path}      //= [];

  # ^lising
  my $path=$O{path};
  delete $O{path};

  # make res for lookup
  my $out     = $self;
  my $path_re = [map {
    my $s="\Q$ARG";
    qr[^$s$]x;

  } @$path];

  # get nodes accto path
  for my $i(0..@$path-1) {

    my $key   = $path->[$i];
    my $re    = $path_re->[$i];

    my $cache = $out->{fcache};

    # perform lookup and store results
    my $nd=$out->cached_fetch($key,$re,%O);

    # make new if needed
    if(! $O{existing}) {
      $out=($nd) ? $nd : $out->inew($key);

    # abort on missing
    } elsif(! $O{throw}) {
      $out=$nd;
      last if ! $out;

    # throw on missing
    } else {

      $out=(! $nd)
        ? throw_bad_fetch(@$path)
        : $nd
        ;

    };

  };


  # cache result and give
  $self->{'*fetch'} = $out;
  return $out;

};

# ---   *   ---   *   ---
# ^errme

sub throw_bad_fetch(@path) {

  my $path=join q[/],@path;

  errout(

    q[Invalid path; FET <%s>],

    args => [$path],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# ^store and reuse fetch results

sub cached_fetch($self,$key,$re,%O) {

  my $cache=$self->{fcache};

  # key in cache points to leaf
  my $have =
     exists  $cache->{$key}
  && defined $cache->{$key}
  ;

  # ^leaf is indeed within branch
  my $valid =
     $have
  && $cache->{$key}->{parent} eq $self
  ;

  # ^remove invalid entries
  delete $cache->{$key} if ! $valid && $have;

  # ^run lookup for invalidated keys
  my $out=(! $valid)
    ? $self->branch_in($re,%O)
    : $cache->{$key}
    ;

  # ^store and give result
  $cache->{$key}=$out;
  return $out;

};

# ---   *   ---   *   ---
# get reference to value of
# first leaf

sub fvalue($self) {
  my $out=$self->{leaves}->[0];
  return \$out->{value};

};

# ---   *   ---   *   ---
# get first node in tree

sub root($self) {

  my $root=$self;
  my $depth=0;

  while(defined $root->{parent}) {
    $root=$root->{parent};
    $depth++;

  };

  return ($root,$depth);

};

# ---   *   ---   *   ---
# get list of parent nodes

sub ances_list($self,%O) {

  # defaults
  $O{max_depth} //= 0x24;


  # walk upwards
  my $anchor = $self;
  my $depth  = 0;
  my @out    = ($anchor->{value});

  while($anchor->{parent}) {

    $anchor=$anchor->{parent};
    unshift @out,$anchor->{value};

    $depth++;


    last if $depth >= $O{max_depth};

  };


  return @out;

};

# ---   *   ---   *   ---
# ^cats parent values recursively

sub ances($self,%O) {

  # defaults
  $O{max_depth} //= 0x24;
  $O{join_char} //= $NULLSTR;


  # get list of nodes
  my @out=$self->ances_list(%O);

  # give catted
  return join $O{join_char},@out;

};

# ---   *   ---   *   ---
# ascends the hierarchy n times

sub walkup($self,$top=undef) {

  # opt defaults
  $top//=-1;


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
# ^similar, return distance from root

sub depth($self) {

  my $out=0;

  while($self->{parent}) {
    $out++;
    $self=$self->{parent};

  };

  return $out;

};

# ---   *   ---   *   ---
# get path from root to leaf
# as a series of indices

sub ancespath($self,$upto=undef) {

  my $out=[];

  while($self->{parent}) {

    unshift @$out,$self->{idex};
    $self=$self->{parent};

    last if $upto && $self eq $upto;

  };


  return $out;

};

# ---   *   ---   *   ---
# ^get node from path

sub from_path($self,$path) {

  my $anchor=$self;
  map {
    $anchor=$anchor->{leaves}->[$ARG];

  } @$path;


  return $anchor;

};

# ---   *   ---   *   ---
# return neighboring leaf

sub neigh($self,$offset) {

  my $out   = undef;

  my $par   = $self->{parent};
  my $idex  = $self->{idex}+$offset;
  my $limit = int @{$par->{leaves}};

  goto TAIL if ! $par;

  $out=($idex >= 0 && $idex < $limit)
    ? $par->{leaves}->[$idex]
    : undef
    ;

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# ^aliases

sub get_prev($self) {
  return $self->neigh(-1);

};

sub get_next($self) {
  return $self->neigh(1);

};

# ---   *   ---   *   ---
# clears all branches matching re

sub sweep($self,$re) {

  map {
    $ARG->discard()

  } $self->branches_in($re);

};

# ---   *   ---   *   ---
# get branch is N layers deep

sub deepchk($self,$depth=1) {

  my $out     = 0;
  my $i       = 0;

  my @pending = @{$self->{leaves}};

  while(@pending) {

    my $nd=shift @pending;
    next if $i > $depth;

    if($nd eq 0) {
      $i--;
      next;

    } elsif($nd eq 1) {
      $i++;
      next;

    };

    my @lv=@{$nd->{leaves}};

    if(@lv) {
      unshift @lv,1;
      push    @lv,0;

      $out|=1*($i==$depth);

    };

    unshift @pending,@lv;

  };

  return $out;

};

# ---   *   ---   *   ---
# converts branch to nested hash

sub bhash($self,@type) {

  return { map {

    my @ar=(!$ARG->deepchk(0))
      ? $ARG->branch_values()

      # just give the branch
      # to avoid recursion
      : $ARG #->bhash()
      ;

    $ARG->{value}=>(!(shift @type))
      ? $ar[0]
      : [@ar]
      ;

  } @{$self->{leaves}} };

};

# ---   *   ---   *   ---
# push node array to leaves

sub pushlv($self,@pending) {

  while(@pending) {

    my $node=shift @pending;
    my $par=$node->{parent};

    $node->{parent}=$self;

    push @{$self->{leaves}},$node;

    if($par && $par != $node->{parent}) {
      $par->pluck($node);
      $node->{parent}=$self;

    };

  };

  $self->idextrav();
  return;

};

# ---   *   ---   *   ---
# removes all children from self

sub clear($self) {
  $self->{leaves}=[];

};

# ---   *   ---   *   ---
# ^removes children from leaves

sub clear_branches($self) {

  for my $leaf(@{$self->{leaves}}) {
    $leaf->clear();

  };

};

# ---   *   ---   *   ---
# discard blank nodes

sub cllv($self) {

  $self->{leaves}=[grep {
     defined $ARG
  && defined $ARG->{value}

  } @{$self->{leaves}}];

  $self->idextrav();

  return;

};

# ---   *   ---   *   ---
# puts new nodes anywhere on the tree

sub insert($self,$pos,@list) {

  my ($head,$tail)=$self->insert_prologue($pos);
  my @insert=map {$self->inew($ARG)} @list;

  $self->insert_epilogue(

    head   => $head,
    insert => \@insert,

    tail   => $tail,

  );

  return @insert;

};

# ---   *   ---   *   ---
# ^same, merges with subtrees

sub insertlv($self,$pos,@list) {

  my ($head,$tail)=$self->insert_prologue($pos);

  # relocate leaves to new branch
  map {$ARG->{parent}=$self} @list;

  # ^update self leaves
  $self->insert_epilogue(

    head   => $head,
    insert => \@list,

    tail   => $tail,

  );

  return @list;

};

# ---   *   ---   *   ---
# ^repeated for both

sub insert_prologue($self,$pos) {

  my @ar=@{$self->{leaves}};

  my @head=();
  my @tail=();

  # cut array at position
  if($pos) {
    @head=@ar[0..$pos-1]

  };

  if($pos<=$#ar) {
    @tail=@ar[$pos..$#ar];

  };

  return \@head,\@tail;

};

# ---   *   ---   *   ---
# ^end-of

sub insert_epilogue($self,%h) {

  my @leaves=(

    @{$h{head}},
    @{$h{insert}},

    @{$h{tail}},

  );

  # ^overwrite
  $self->{leaves}=\@leaves;
  $self->idextrav();

};

# ---   *   ---   *   ---
# replaces a node in the hierarchy

sub repl($self,$other) {

  my $ref=$self->{parent}->{leaves};
  my $i=-1;


  for my $node(@$ref) {

    $i++;
    if($node eq $self) {
      last;

    };

  };


  if($i>=0) {

    $other->{parent}=$self->{parent};
    $ref->[$i]=$other;

    $self->{parent}->cllv();

  };

  return;

};

# ---   *   ---   *   ---
# ^same, fixes some issues when moving
# large branches around

sub deep_repl($self,$other) {

  state $fbid_key_re=qr{^(?: idex|parent)$}x;
  $self->repl($other) if $self->{parent};

  for my $key(keys %$self) {

    next if $key=~ m[$fbid_key_re];
    $self->{$key}=$other->{$key};

  };

  my @lv=$other->pluck_all();

  $self->clear();
  $self->pushlv(@lv);

};

# ---   *   ---   *   ---
# ^replaces *just* the values of nodes

sub deep_value_repl($self,$re,$new) {

  for my $branch($self->branches_in($re)) {
    $branch->{value}=~ s[$re][$new]sxgm;

  };

};

# ---   *   ---   *   ---
# replaces node with it's leaves

sub flatten_branch($self,%O) {

  return if ! $self->{parent};

  # opt defaults
  $O{keep_root}//=0;

  my @move = $self->pluck(@{$self->{leaves}});
  my $par  = $self->{parent};

  $par->idextrav();

  my $idex = $self->{idex};
  my @ar   = @{$par->{leaves}};

  # get leaves to move
  if($O{keep_root}) {unshift @move,$self};
  if($idex) {unshift @move,@ar[0..$idex-1]};
  if($idex<$#ar) {push @move,@ar[$idex+1..$#ar]};

  # wipe branch and reset its leaves
  $par->clear();
  $par->pushlv(@move);
  $par->cllv();

  return $par->{leaves}->[$idex];

};

# ---   *   ---   *   ---
# ^bat, for all immediate children

sub flatten_branches($self,%O) {

  map {
    $ARG->flatten_branch()

  } @{$self->{leaves}};

};

# ---   *   ---   *   ---
# removes leaves from node

sub pluck($self,@pending) {

  my @plucked=();

  for my $leaf(@{$self->{leaves}}) {

    if(grep {$leaf && $leaf eq $ARG} @pending) {

      push @plucked,$leaf;

      $leaf->{parent}  = undef;
      $leaf->{plucked} = 1;

      $leaf            = undef;

    };

  };

  $self->cllv();
  return @plucked;

};

# ---   *   ---   *   ---
# ^by idex

sub ipluck($self,@pending) {
  return $self->pluck(
    map {$self->{leaves}->[$ARG]} @pending

  );

};

# ---   *   ---   *   ---
# ^clear

sub pluck_all($self) {
  return $self->pluck(@{$self->{leaves}});

};

# ---   *   ---   *   ---
# ^ask parent for retirement

sub discard($self) {
  $self->{parent}->pluck($self)
  if $self->{parent};

};

# ---   *   ---   *   ---
# resets indices in branch

sub idextrav($self) {

  my $i=0;
  for my $child(@{$self->{leaves}}) {
    $child->{idex}=$i++;
    $child->{plucked}=0;

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
# sorts leaves in tree
# accto some variable buried
# deep into the hashmap

sub hvarsort($self,@path) {


  # get table of [node=>var]
  my %tab=map {

    my $nd  = $ARG;
    my $dst = \$nd;

    map {$dst=\$$dst->{$ARG}} @path;

    $nd=>[$$dst,$nd];

  } @{$self->{leaves}};

  # ^sort nodes based on var
  my @leaves=map {
    $tab{$ARG}->[1]

  } sort {
    $tab{$a}->[0]
  > $tab{$b}->[0]

  } keys %tab;

  # ^reset
  $self->{leaves}=\@leaves;
  $self->idextrav();

};

# ---   *   ---   *   ---
# ^recursive

sub rec_hvarsort($self,@path) {

  $self->hvarsort(@path);

  my @pending=@{$self->{leaves}};

  while(@pending) {

    my $nd=shift @pending;
    $nd->hvarsort(@path);

    unshift @pending,@{$nd->{leaves}};

  };

};

# ---   *   ---   *   ---
# gives list of leaves in tree that
# dont have leaves of their own

sub leafless($self,%O) {

  # defaults
  $O{i}           //= undef;
  $O{give_parent} //= 0;
  $O{max_depth}   //= 0x24;


  my $depth  = 0;

  my @leaves = ($self);
  my @out    = ();


  # walk the hierarchy
  while(@leaves) {

    $self=shift @leaves;

    # manage depth
    if($self eq 0) {$depth--;next}
    elsif($self eq 1) {$depth++;next};


    # consider elem if it has no leaves
    if(! @{$self->{leaves}}) {

      # ^gets *par* of elem
      if($O{give_parent}) {

        my $par=$self->{parent};

        push @out,$par

        if  defined $par
        &&! int grep {$par eq $ARG} @out;

        next;

      # ^elem itself
      } else {
        push @out,$self;

      };

    };


    # cap at max depth
    next if $depth >= $O{max_depth};
    unshift @leaves,1,@{$self->{leaves}},0;

  };


  # optionally return a specific element
  # else whole array is given
  @out=$out[$O{i}] if defined $O{i};
  return @out;

};

# ---   *   ---   *   ---
# give list of nodes that have children

sub hasleaves($self,%O) {

  $O{max_depth}//=0x24;
  $O{keep_root}//=0;

  my $depth=0;
  my @pending=();

  if($O{keep_root}) {
    push @pending,$self;

  } else {
    push @pending,@{$self->{leaves}};

  };

  my @result=();

  while(@pending) {

    $self=shift @pending;
    if($self eq 0) {$depth--;next}
    elsif($self eq 1) {$depth++;next};

    push @result,$self if(@{$self->{leaves}});

    if($depth>=$O{max_depth}) {next};
    unshift @pending,1,@{$self->{leaves}},0;

  };

  return (@result);

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


  my @found=();
  my @leaves=();

  my $depth=0;
  if($O{keep_root}) {
    push @leaves,$self;

  } else {
    push @leaves,@{$self->{leaves}};

  };


  # look for matches recursively
  while(@leaves) {

    $self=shift @leaves;
    if($self eq 0) {$depth--;next}
    elsif($self eq 1) {$depth++;next};


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

  };


  # return matches
  return @found;

};

# ---   *   ---   *   ---
# gives list of branches starting with value

sub branches_in($self,$lookfor,%O) {

  # defaults
  $O{keep_root}   //= 1;
  $O{max_depth}   //= 0x24;
  $O{first_match} //= 0;


  my @leaves = ();
  my @found  = ();

  my $depth  = 0;


  # keep or discard root node
  if($O{keep_root}) {
    push @leaves,$self;

  } else {
    push @leaves,@{$self->{leaves}};

  };


  # look for matches recursively
  while(@leaves) {

    $self=shift @leaves;

    # ^manage recursion depth
    $depth--,next if $self eq 0;
    $depth++,next if $self eq 1;


    # match found
    if($self->{value}=~ $lookfor) {
      push @found,$self;
      last if $O{first_match};

    };


    # ^stop at max depth
    next if $depth >= $O{max_depth};
    unshift @leaves,1,@{$self->{leaves}},0;


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
# ^shorthands

sub branch_values($self) {
  return map {$ARG->{value}} @{$self->{leaves}};

};

sub leaf_value($self,$idex) {
  return $self->{leaves}->[$idex]->{value};

};

sub leafless_values($self,%O) {
  return map {$ARG->{value}} $self->leafless(%O);

};

# ---   *   ---   *   ---
# return nodes in tree that
# match any uid in list

sub find_uid($self,@list) {

  my @Q   = ($self);
  my @out = ();

  my $re  = re_eiths \@list,whole=>1;

  while(@Q) {

    my $nd=shift @Q;

    push @out,$nd if $nd->{-uid}=~ $re;
    unshift @Q,@{$nd->{leaves}};

  };


  return @out;

};

# ---   *   ---   *   ---
# reverse walk
#
# for the weird edge-cases when
# you need to apply a function to
# the whole tree, but backwards
#
# absolutely inefficient,
# use with care

sub rwalk($self) {

  my @out     = ();
  my @pending = ($self);

  while(@pending) {

    my $nd=shift @pending;
    my @lv=@{$nd->{leaves}};

    push    @out,$nd;
    unshift @pending,@lv;

  };

  return reverse @out;

};

# ---   *   ---   *   ---
# flattens tree and stringifies it

sub to_string($self,%O) {

  # args defaults
  $O{max_depth} //= 0x24;
  $O{keep_root} //= 0;
  $O{value}     //= 'value';
  $O{join_char} //= q[ ];

  # ^handle walk array
  my @leaves=();
  if($O{keep_root}) {
    push @leaves,$self;

  } else {
    push @leaves,@{$self->{leaves}};

  };


  # recurse and cat to string
  my @out   = ();
  my $depth = 0;

  while(@leaves) {

    $self=shift @leaves;


    # manage depth
    $depth--,next if $self eq 0;
    $depth++,next if $self eq 1;

    # ^cat
    $self->{$O{value}} //= $NULLSTR;
    push @out,$self->{$O{value}};


    # stop at max depth
    next if $depth >= $O{max_depth};
    unshift @leaves,1,@{$self->{leaves}},0;

  };


  my $s=join $O{join_char},@out;

  strip(\$s);
  return $s;

};

# ---   *   ---   *   ---
# ^inplace

sub flatten_to_string($self,%O) {
  $self->{value}=$self->to_string(%O);
  $self->clear();

};

# ---   *   ---   *   ---

sub leaves_between($self,$i0,$i1,@branches) {

  my @leaves=@{$self->{leaves}};
  @branches=@leaves if !@branches;

  my $cur=$branches[$i0];
  my $ahead=$branches[$i1];

  my $beg=$cur->{idex};
  my $end;

  if(defined $ahead) {
    $end=$ahead->{idex}-1;

  } else {
    $end=$#leaves;

  };

  return @leaves[$beg+1..$end];

};

# ---   *   ---   *   ---
# similar to branch_in, except it looks within
# it's own leaves starting at a child's idex

sub match_from($self,$ch,$pat) {

  my @pending=@{$self->{leaves}};
  @pending=@pending[$ch->{idex}+1..$#pending];

  my $out=undef;

  while(@pending) {

    $self=shift @pending;
    if($self->{value}=~ $pat) {
      $out=$self;
      last;

    };

  };

  return $out;

};

# ---   *   ---   *   ---
# ^returns range of leaves
# from child up to match

sub match_until($self,$ch,$pat,%O) {

  # defaults
  $O{iref}      //=0;
  $O{inclusive} //=0;

  my @out  = ();
  my @path = ();

  my @pending = @{$self->{leaves}};
  @pending    = @pending[$ch->{idex}+1..$#pending];


  # walk the leaves
  while(@pending) {

    $self=shift @pending;

    # remember idex
    if($O{iref}) {
      ${$O{iref}}++;

    };

    # cut when pattern found
    if($self->{value}=~ $pat) {
      @out=@path;

      # save end token
      if($O{inclusive}) {
        push @out,$self;

      };

      last;


    # save middle token
    } else {
      push @path,$self;

    };

  };

  return @out;

};

# ---   *   ---   *   ---
# ^all nodes from one
# child up to another

sub match_until_other($self,$a,$b,%O) {

  # defaults
  $O{inclusive} //= 1;

  # get range of elements
  my @out     = ();
  my $idex    = $a->{idex};

  my @pending = @{$self->{leaves}};
     @pending = @pending[$idex+1..$#pending];

  # ^walk
  while(@pending) {

    my $nd=shift @pending;

    # exit 1 element early if exclusive
    if($nd eq $b &&! $O{inclusive}) {
      last;

    };

    # else push all elems
    push @out,$nd;
    last if $nd eq $b;

  };

  return @out;

};

# ---   *   ---   *   ---
# return all children from node onwards

sub all_from($self,$ch,%O) {

  # defaults
  $O{inclusive} //= 0;
  $O{cap}       //= 0;

  my @pending = @{$self->{leaves}};

  my $limit   = ($O{cap} && $O{cap}<=$#pending)
    ? $O{cap}
    : $#pending
    ;

  croak "no child leaves"
  if ! defined $ch->{idex};

  @pending=@pending[$ch->{idex}+1..$limit];

};

# ---   *   ---   *   ---
# get all nodes from self
# up to pattern,
#
# or all nodes from self
# to end if that fails

sub match_up_to($self,$pattern) {

  my @out=$self->{parent}->match_until(
    $self,$pattern

  );

  # ^on fail
  @out=$self->{parent}->all_from(
    $self

  ) if ! @out;

  return @out;

};

# ---   *   ---   *   ---
# tree leaves match a specific
# sequence of patterns

sub match_sequence($self,@seq) {

  # early exit if sizes don't match
  my @pending=@{$self->{leaves}};
  return undef if @pending < @seq;


  # current/first
  my $idex = 0;
  my $pos  = 0;


  # ^else walk
  top:

  for my $re(@seq) {

    my $nd=$pending[$idex++];

    # no match
    if(! ($nd->{value}=~ $re)) {

      # retry with new position?
      $pos++;
      $idex=$pos;

      my $left=$#pending - $pos;
      goto top if $left >= $#seq;

      # ^nope, fail
      return undef;

    };

  };


  # give pos if all matched
  return $pos;

};

# ---   *   ---   *   ---
# ^attempt a *series* of
# sequences

sub match_series($self,@series) {

  my $idex=0;

  # attempt all sequences in series
  #
  # break and give sequence idex
  # on first match
  for my $seq(@series) {
    my $pos=$self->match_sequence(@$seq);
    return ($idex,$pos) if defined $pos;

    $idex++;

  };

  # else fail
  return undef;

};

# ---   *   ---   *   ---
# get next leaf in a cannonical walk

sub next_leaf($self) {

  my $ahead=(@{$self->{leaves}})
    ? $self->{leaves}->[0]
    : $self->next_branch()
    ;

  return $ahead;

};

# ---   *   ---   *   ---
# ^iv-of

sub prev_leaf($self) {

  my $ahead=(@{$self->{leaves}})
    ? $self->{leaves}->[-1]
    : $self->next_branch(-1)
    ;

  return $ahead;

};

# ---   *   ---   *   ---
# ^get neighboring branch

sub next_branch($self,$step=1) {

  my $idex  = $self->{idex}+$step;
  my $pool  = $self->{parent};

  my $ahead = ($idex >= 0)
    ? $pool->{leaves}->[$idex]
    : undef
    ;

  if(! defined $ahead) {

    $ahead=($self->{parent})
      ? $self->{parent}->next_branch($step)
      : undef
      ;

  };

  return $ahead;

};

# ---   *   ---   *   ---
# push filtered leaves of
# one tree to another

sub filter($self,$other,%O) {

  # defaults
  $O{discard} //= $NO_MATCH;

  my @pending = @{$self->{leaves}};
  my @move    = ();

  while(@pending) {

    my $lv=shift @pending;

    push @move,$lv
    if ! ($lv->{value}=~ $O{discard});

  };

  $other->pushlv(@move);

};

# ---   *   ---   *   ---
# draw hierarchy, such that:
#
#   (root)
#   \-->(child)
#   .  \-->(gchild)

sub draws($depth,$prev) {


  my $branch=($depth)
    ? '.  ' x ($depth-1).'\-->'
    : $NULLSTR
    ;

  return ($depth < $prev)
    ? Tree::drawp($depth) . "\n$branch"
    : $branch
    ;

};

# ---   *   ---   *   ---
# add additional spacing for clarity
# in-between nested branches

sub drawp($depth) {
  return '.  ' x $depth;

};

# ---   *   ---   *   ---
# string repr for single leaf

sub repr($self,$depth,$prev,%O) {


  # default to null or skip excluded
  my $v=$self->{value};
  $v //= sprintf "%016X",$NULL;

  return undef if $v=~ $O{-x};


  # recursing optional ;>
  return '[sub-tree]'
  if Tree->is_valid($v) &&! $O{vrecurse};


  # make repr for value
  my $keep=$depth;

  $v=(St->is_valid($v))


    # have repr method?
    ? $v->prich(

      %O,

      -bufio => undef,

      leaf   => \$keep,
      mute   => 1,

    )

    # else give as-is!
    : $v

    ;


  return ($v,$keep);

};

# ---   *   ---   *   ---
# ^dbout whole tree

sub prich($self,%O) {

  # I/O defaults
  my $out=ioprocin(\%O);
  $O{max_depth} //= 0x24;
  $O{vrecurse}  //= 0;
  $O{-x}        //= $NO_MATCH;

  # previous/current recursion depth
  my $prev  = 0;
  my $depth = 0;


  # get to walkin...
  my $root = $self;
  my @Q    = ($self);

  while(@Q) {


    # handle depth
    $self=shift @Q;

    if(! $self) {

      # ^restore previous
      $depth-- if defined $self;
      next;

    };


    # leaf valid for dbout?
    my @tail = (undef);
    my @lv   = @{$self->{leaves}};

    if(! $self->{-skipio}) {


      # get value
      my ($v,$keep)=$self->repr(
        $depth,$prev,%O

      );

      next if ! defined $v;


      # ^nope, keep going
      my $branch=Tree::draws($depth,$prev);

      $prev=$depth;
      $depth++ if int @lv;

      push @$out,"$branch$v\n";
      @tail=(0);


      # irup received?
      if(! defined $keep) {
        shift @Q while defined $Q[0];
        next;

      };

    };


    # go next if below limit
    next if $depth >= $O{max_depth};

    unshift @Q,@lv,@tail
    if int @lv;

  };


  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
