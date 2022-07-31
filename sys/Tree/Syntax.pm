#!/usr/bin/perl
# ---   *   ---   *   ---
# SYNTAX TREE
# Holds your tokens
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Tree::Syntax;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use English qw(-no_match_vars);
  use Scalar::Util qw/blessed/;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

  use parent 'Tree';

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use Shwl;

# ---   *   ---   *   ---
# info

  our $VERSION=v3.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $OPERATOR=>qr{
    node_op=HASH\(0x[0-9a-f]+\)

  }x;

# ---   *   ---   *   ---

sub nit($class,$frame,@args) {

  my $tree=Tree::nit($class,$frame,@args);
  return $tree;

};

# ---   *   ---   *   ---

sub tokenize($self) {

  my $body=$self->{value};
  my $lang=$self->{frame}->{master}->{lang};

  my $cut_token_re=$Shwl::CUT_RE;
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
    || !length stripline($elem)

    ) {last};

    push @elems,$elem;

  };

# ---   *   ---   *   ---

  if(@elems) {
    $self->{value}=shift @elems;

    for my $elem(@elems) {

# ---   *   ---   *   ---
# NOTE: why is this bit here?
#
#   ifdef __cplusplus
#     extern 'C' { be damned };
#
#   endif
#
# ^that's why

      if($elem=~ qr{^:__PREPROC}) {
        $self=(defined $self->{parent})
          ? $self->{parent}
          : $self
          ;

      };

# ---   *   ---   *   ---

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

};

# ---   *   ---   *   ---
# expands the tree to solve expressions

sub subdiv($self) {

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
    $leaf->pushlv($root->pluck(@move));
    goto TOP;

# ---   *   ---   *   ---

  };if(@leaves) {

    $root=shift @leaves;
    goto TOP;

  };

  return;

};

# ---   *   ---   *   ---
# solves operations across the hierarchy

sub collapse($self,%opt) {

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

# ---   *   ---   *   ---

    if($self->{value}=~ m/^$OPERATOR$/) {

      if(

         defined $only_if
      && !($self->{value}->{op}=~ m/^$only_if/)

      ) {goto SKIP};

      push @solve,$self;

    };

# ---   *   ---   *   ---

SKIP:
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

};

# ---   *   ---   *   ---
# makes a node hierarchy from a
# delimiter-[values]-delimiter sequence

sub delimbrk($self,$i) {

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
      $anchor->pushlv(@$ref);

    };

# ---   *   ---   *   ---

  };

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
1; # ret
