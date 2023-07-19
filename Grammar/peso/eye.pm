#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO EYE
# One *is* one, though not idem
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::eye;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;
  use Grammar;

  use Grammar::peso::common;
  use Grammar::peso::ops;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_EYE);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  sub Frame_Vars($class) { return {
    %{Grammar->Frame_Vars()},

  }};

  Readonly our $PE_EYE=>
    'Grammar::peso::eye';

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    %{$PE_COMMON->get_retab()},
    %{$PE_OPS->get_retab()},

  };

  # operator or subscript
  $REGEX->{q[op-or-subs]}=qr{(?:

    $REGEX->{ops}
  | ^\[

  )}x;

# ---   *   ---   *   ---
# make expression subtrees from codestring

sub expr_split($self,$s) {

  # split codestring into expressions
  my $re=$REGEX->{q[sep-delim]};
  my @tk=split $re,$s;
  my @ar=grep {defined $ARG} map {$ARG} @tk;

  # ^process comma-separated lists
  map {
    $self->clist_split(\$ARG)

  # ^for non-nested exprs
  } grep {
    ! ($ARG=~ $re)

  } @ar;

  # ^unpack results of split for filtered
  @ar=map {(is_arrayref($ARG))
    ? map {split m[($COMMA_RE)],$ARG} @$ARG
    : $ARG
    ;

  } @ar;

  # ^turn lists into branches
  my @lists = $self->clist_join(@ar);
  my $root  = $self->lists_to_tree(@lists);

# TODO: recursive token to branch
# TODO: cast token array to tree

  $self->tree_grow($root->{leaves}->[0]);
  map {$self->tree_grow($ARG)} @{$root->{leaves}};

  $root->prich();

};

# ---   *   ---   *   ---
# ^split by lists

sub clist_split($self,$sref) {

  my $seps  = qr{\s* (,|($REGEX->{ops})) \s*}x;
  my $lists = qr{(?: (?!< ,) \s+)}x;

  $$sref=~ s[$seps][$1]sxmg;
  $$sref=[split $lists,$$sref];

  array_filter($$sref);

};

# ---   *   ---   *   ---
# ^join disconnected lists

sub clist_join($self,@ar) {

  state $comma = qr{^\s* , \s*}x;
  state $ops   = qr{$REGEX->{ops} \s* $}x;

  my @out     = ();

  my $idex    = 0;
  my $ahead   = 0;
  my $pending = 0;

  array_filter(\@ar);

  # walk token list
  for my $j(0..$#ar) {

    my $s    = $ar[$j];

    my $have = int($s=~ s[$comma][]);
    my $cat  = int($s=~ $ops);

    my $skip = ! length $s;

    # current/last begs with
    # comma or operator
    if($pending || $have || $cat) {
      $pending = int(
         ($have && $skip)
      || ($cat)

      );

      $idex    = -1;

    # ^none, consider it another list
    } else {
      $idex    = 0;
      $pending = 0;

    };

    next if $skip;

    # push token to list
    $out[$ahead+$idex]//=[];
    push @{$out[$ahead+$idex]},$s;

    $ahead +=! $idex;

  };

  return @out;

};

# ---   *   ---   *   ---
# ^makes token lists into subtree

sub lists_to_tree($self,@lists) {

  my $branch = $self->{p3}->init('TOP');
  my $anchor = undef;

  my $i      = 0;

  # walk arrays of tokens
  for my $ar(@lists) {

    $anchor=$branch->init(
      sprintf "\$%04X",$i++

    );

    # split at operators if token
    # is not a nested expression
    for my $tok(@$ar) {

      my @s=(! ($tok=~ $REGEX->{q[sep-delim]}))
        ? (split $REGEX->{q[op-or-subs]},$tok)
        : ($tok)
        ;

      map {$anchor->init($ARG)} @s;

    };

  };

  return $branch;

};

# ---   *   ---   *   ---
# ^expands a branch in tree of tokens

sub tree_grow($self,$branch) {

  my $anchor  = undef;
  my @pending = @{$branch->{leaves}};

  my $expand = 0;
  my $i      = 0;

  # walk branch
  while(@pending) {

    # get current + next
    my $lv    = shift @pending;
    my $ahead = $lv->neigh(1);

    # end of branch
    if(! $ahead) {
      $anchor->pushlv($lv) if $anchor;
      last;

    };

    # next is operator, cat to current
    $expand=
      $ahead->{value}=~ $REGEX->{q[op-or-subs]};

    if($expand) {

      # make new sub-branch if not present
      if(! $anchor) {

        ($anchor)=$branch->insert(
          $lv->{idex},(sprintf "\$%04X",$i++)

        );

      };

      # ^cat current and next to sub-branch
      shift @pending;
      $anchor->pushlv($lv,$ahead);

    # ^end of sub-branch
    } elsif($anchor) {
      $anchor->pushlv($lv);
      $anchor=undef;

    };

  };

};

# ---   *   ---   *   ---
# ^do not generate a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# test

my $ice=Grammar::peso::eye->new();
$ice->expr_split(q~
  a,b,c
+ (expr,expr),{fn args}

1+1,2*3

~);

# ---   *   ---   *   ---
1; # ret
