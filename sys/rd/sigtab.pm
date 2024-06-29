#!/usr/bin/perl
# ---   *   ---   *   ---
# RD SIGTAB
# Tables of patterns...
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::sigtab;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT=>{

    main => undef,
    tab  => {},

    keyw => undef,
    prev => [],

  },

  sig_t => 'rd::sig',

};

# ---   *   ---   *   ---
# get element

sub fetch($self,$keyw) {
  return $self->{tab}->{$keyw};

};

# ---   *   ---   *   ---
# ^get and validate!

sub valid_fetch($self,$keyw) {

  my $have=$self->fetch($keyw);
  my $main=$self->{main};

  $main->throw_undefined(
    'KEY',$keyw,'non','lx'

  ) if ! $have;


  return $have;

};

# ---   *   ---   *   ---
# make table entry

sub begin($self,$keyw) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # save state
  push @{$self->{prev}},$self->{keyw}
  if defined $self->{keyw};


  # set current
  $self->{keyw}=$keyw;


  # make new entry
  my $dst=$self->{tab}->{$keyw}={};

  $dst->{sig} = [];
  $dst->{fn}  = $NOOP;
  $dst->{re}  = $l1->re(SYM=>$keyw);
  $dst->{obj} = undef;

  return;

};

# ---   *   ---   *   ---
# pushes a new pattern array
# to table

sub pattern($self,@seq) {

  # get ctx
  my $keyw  = $self->{keyw};
  my $dst   = $self->{tab}->{$keyw};
  my $sig_t = $self->sig_t;

  # ^make new signature and push
  my $sig = $sig_t->new(\@seq);

  push @{$dst->{sig}},$sig;


  return;

};

# ---   *   ---   *   ---
# ^generate multiple from descriptor

sub complex_pattern($self,@seq) {

  use Fmat;

  # ~
  my @defv  = ();
  my $elems = (int @seq / 2)-1;
  my $total = (1 << $elems+1)-1;


  # array as hash
  my @sk=array_keys   \@seq;
  my @sv=array_values \@seq;

  # ^walk
  my @out=map {

    my $key   = $sk[$ARG];
    my $value = $sv[$ARG];

    my $defv  = $value->{defv};

    push @defv,$defv;
    [$key=>$value->{re}];


  } 0..$#sk;


  # what follows is a combinational problem:
  #
  # * set bits of the mask represent fixed values
  #   that are non-optional to this pattern
  #
  # * unset bits are the optional elements of
  #   the signature
  #
  #
  # we obtain all possible combinations by
  # counting from zero to the total number of
  # possibilities
  #
  # a binary OR of this counter and the mask
  # tells us which values to use for a pattern
  #
  # this way, all combinations are walked
  #
  #
  # we begin by getting the mask

  my $mask=do {

    my ($bit,$out)=(0,0);

    map {$out |=! defined($ARG) << $bit++}
    @defv;

    $out;

  };


  # now iter until the counter is equal
  # to the total number of combinations

  my $cnt  = 0;
  my @have = ();

  while($cnt <= $total) {

    $cnt |= $mask;


    # decide which elements to include in the
    # signature variant by looking at which
    # bits of the counter are set

    my @alt=map {


      # set bit means this value is included
      if($cnt & (1 << $ARG)) {
        $out[$ARG];

      # unset bit means ignore it
      } else {
        [$out[$ARG]->[0]=>$defv[$ARG]]

      };

    } 0..$elems;


    # save signature variant and go next
    push @have,\@alt;
    $cnt++;

  };


  # register variants in inverse order
  map {$self->pattern(@$ARG)} reverse @have;


  return;

};

# ---   *   ---   *   ---
# ^binds function to pattern arrays

sub function($self,$fn) {

  # get ctx
  my $keyw = $self->{keyw};
  my $dst  = $self->{tab}->{$keyw};

  # copy
  $dst->{fn} = $fn;

  return;

};

# ---   *   ---   *   ---
# reset the keyword regex!

sub regex($self,$re) {

  # get ctx
  my $main = $self->{main};
  my $keyw = $self->{keyw};
  my $dst  = $self->{tab}->{$keyw};

  # copy
  $dst->{re} = $re;

  return;

};

# ---   *   ---   *   ---
# if matching tree nodes,
# use sibling nodes only!

sub set_flat($self,$x) {

  # get ctx
  my $main = $self->{main};
  my $keyw = $self->{keyw};
  my $dst  = $self->{tab}->{$keyw};

  # copy
  $dst->{flat} = $x;

  return;

};

# ---   *   ---   *   ---
# assigns reference as the "self"
# to be utilized by function

sub object($self,$obj) {

  # get ctx
  my $main = $self->{main};
  my $keyw = $self->{keyw};
  my $dst  = $self->{tab}->{$keyw};

  # copy
  $dst->{obj} = $obj;

  return;

};

# ---   *   ---   *   ---
# merges data on current entry

sub build($self) {


  # get ctx
  my $keyw = $self->{keyw};
  my $dst  = $self->{tab}->{$keyw};
  my $ar   = $dst->{sig};


  # get first definition of default
  # value for attr, across all signatures
  my $defv={};
  map {$ARG->attrs_to_hash(defv=>$defv)} @$ar;

  # now add default value to signatures
  # that do not explicitly declare it!
  map {$ARG->hash_to_attrs(defv=>$defv)} @$ar;


  # blankout current and give
  $self->{keyw}=shift @{$self->{prev}};

  return $dst;

};

# ---   *   ---   *   ---
# match input against pattern array

sub matchin($self,$keyw,$x,%O) {


  # get ctx
  my $sigar=$keyw->{sig};

  # fout
  my $data={};


  # have signature match?
  for my $sig(@$sigar) {
    $data=$sig->match($x,%O);
    last if length $data;

  };

  return $data;

};

# ---   *   ---   *   ---
# match against tree

sub matchtree($self,$keyw,$x,%O) {

  # get tree root matches keyword
  my $have=$x->{value} =~ $keyw->{re};
     $have=($have) ? $x : undef ;

  # ^if not fixed, look into leaves on fail!
  $have=$x->branch_in($keyw->{re})
  if ! $have &&! $O{fix};

  return $have;

};

# ---   *   ---   *   ---
# ^match keyword
#
# "fix" forces the keyword to be
# the first token!

sub matchkey($self,$keyw,$x,%O) {


  # defaults
  $O{fix} //= 0;


  # have tree?
  if(Tree->is_valid($x)) {
    $self->matchtree($keyw,$x,%O);

  # have array?
  } elsif(is_arrayref $x) {

    # get first match
    my @match=grep {
      (Tree->is_valid($ARG))
        ? $self->matchtree($keyw,$ARG,%O)
        : $ARG=~ $keyw->{re}
        ;

    } @$x;

    return () if ! @match;

    # ^get index of first match!
    my $idex=array_iof $x,$match[0];


    # ensure first match is first elem?
    if($O{fix}) {

      return (! $idex)

        ? [@{$x}[1..@$x-1]]
        : ()
        ;

    # ^nope, give slice at any position!
    } else {
      return [@{$x}[$idex..@$x-1]];

    };


  # have plain value!
  } else {
    return $x=~ $keyw->{re};

  };

};

# ---   *   ---   *   ---
# ^keyword+input

sub match($self,$keyw,$x,%O) {

  # defaults
  $O{reroot} //= 0;

  # get keyword meta?
  $keyw=$self->valid_fetch($keyw)
  if ! ref $keyw;

  # match input against keyword
  my $in=$self->matchkey($keyw,$x,%O);
  return null if ! defined $in;


  # ^match signature and give
  my $data=$self->matchin($keyw,$in,%O);

  return ($O{reroot})
    ? ($in,$data)
    : $data
    ;

};

# ---   *   ---   *   ---
# walk tree and try to find sequences
# if found, return invoke params

sub find($self,$root,%O) {


  # defaults
  $O{list}    //= [];
  $O{limit}   //= 0x24;
  $O{exclude} //= {};

  # get ctx
  my $tab   = $self->{tab};
  my @which = (! @{$O{list}})
    ? values %$tab
    : @{$O{list}}
    ;

  my $limit = $O{limit};

  delete $O{list};
  delete $O{limit};


  # walk the tree
  my @Q     = @{$root->{leaves}};
  my @out   = ();
  my $depth = 0;

  while(@Q) {

    my $nd   = shift @Q;
    my $deep = exists $O{exclude}->{$nd->{-uid}};

    goto skip if $deep;


    # look for matches...
    for my $keyw(@which) {

      # have a match right here?
      my $flat=($O{flat})
        ? $O{flat}
        : $keyw->{flat}
        ;

      my $have=$self->match(

        $keyw,$nd,

        %O,

        fix  => 1,
        flat => $flat,

      );

      # ^YES
      if(length $have) {
        push @out,[$keyw=>$have,$nd];
        last;

      };


      # have a match deeper down?
      $deep |= length $self->match(

        $keyw,$nd,

        %O,

        fix    => 0,
        flat   => $flat,

        nopush => 1,

      );


    };


    # go next?
    skip:

    if($deep && $depth < $limit) {
      unshift @Q,@{$nd->{leaves}};
      $depth++;

    };

  };

  return @out;

};

# ---   *   ---   *   ---
# execute attached function

sub run($self,$keyw,@args) {

  # get keyword meta?
  $keyw=$self->valid_fetch($keyw)
  if ! ref $keyw;

  # invoke with object?
  return ($keyw->{obj})
    ? $keyw->{fn}->($keyw->{obj},@args)
    : $keyw->{fn}->(@args)
    ;

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {
  return tab => $self->{tab};

};

# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {

  return bless {
    main => undef,
    tab  => $O->{tab},

    keyw => undef,

  },$class;

};

# ---   *   ---   *   ---
1; # ret
