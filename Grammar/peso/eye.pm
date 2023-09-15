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
  use Grammar::peso::value;
  use Grammar::peso::ops;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_EYE);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  sub Frame_Vars($class) { return {
    %{Grammar->Frame_Vars()},

  }};

  sub Shared_FVars($self) {return { map {
    $ARG=>$self->{frame}->{$ARG}

  } qw(-creg -cclan -cproc -cdecl) }};

  Readonly our $PE_EYE=>
    'Grammar::peso::eye';

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    %{$PE_COMMON->get_retab()},
    %{$PE_VALUE->get_retab()},
    %{$PE_OPS->get_retab()},

    subs=>qr{\[},

  };

  # operator or subscript
  $REGEX->{q[op-or-subs]}=qr{(

    $REGEX->{ops}
  | $REGEX->{subs}

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

  map {$self->tree_grow($ARG)} @{$root->{leaves}};
  map {$self->tree_solve($ARG)} @{$root->{leaves}};


  return @{$root->{leaves}};

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
  state $ops   = qr{(?:
    $REGEX->{ops} \s* $
  | ^$REGEX->{q[op-or-subs]}

  )}x;

  my @out     = ();

  my $idex    = 0;
  my $ahead   = 0;
  my $pending = 0;
  my $subs    = 0;
  my $clast   = 0;

  array_filter(\@ar);

  # walk token list
  for my $j(0..$#ar) {

    my $s    = $ar[$j];

    my $have = int($s=~ s[$comma][]);
    my $fore = int($s=~ m[$ops$]);
    my $cat  = int($s=~ m[^$ops]);
    my $subs = int($s=~ $REGEX->{subs});


    # comma before operator
    if($cat && $clast) {
      $pending=0;

    };


    $clast   = $have;
    my $skip = ! length $s;

    # current begs/prev ends with
    # comma or operator
    if($pending || $have || $cat) {

      $pending = int(
          ($have && $skip)
      ||  ($cat)
      &&! $subs

      );

      $idex    = -1 * ($ahead > 0);

    # ^operator at end
    } elsif($fore &&! $cat) {
      $pending = 1;

    # ^none, consider it another list
    } else {
      $idex    = 0;
      $pending = 0;

    };

    # save commas for later
    $out[$ahead+$idex]//=[];
    push @{$out[$ahead+$idex]},','
    if $have && $skip;

    next if $skip;


    # push token to list
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

      array_filter(\@s);
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

  my $subs   = 0;
  my $expand = 0;
  my $duo    = 0;
  my $i      = 0;


  # handle sigil-beg edge-case
  if(@pending >= 2
  && $pending[0]->{value}=~ m[^$REGEX->{sigil}$]

  ) {

    $pending[0]->{value}.=
      $pending[1]->{value};

    $branch->pluck($pending[1]);
    @pending=@{$branch->{leaves}};

  };


  # walk branch
  while(@pending) {

    # get current + next + faar away...
    my $lv    = shift @pending;
    my $ahead = $lv->neigh(1);
    my $far   = $lv->neigh(2);
    my $ffar  = undef;

    # end of branch
    if(! $ahead) {
      $expand=undef;
      goto SKIP;

    };


    # next is operator, cat to current
    $expand=
       $lv->{value}=~ $REGEX->{q[op-or-subs]}
    || $ahead->{value}=~ $REGEX->{q[op-or-subs]}

    ;

    $subs=$ahead->{value}=~ $REGEX->{subs};


    # ^two operators in a row
    if($far) {

      $duo=
         $far->{value}=~ $REGEX->{q[op-or-subs]}
      && $expand
      ;

      $ffar=$lv->neigh(3);

    } else {
      $duo=0;

    };


SKIP:

    if($anchor && $duo && $ffar) {

      $far->{value}=
        "$far->{value}$ffar->{value}";

      $anchor->pushlv($lv,$ahead,$far);
      map {shift @pending} 0..3;

      $ffar->{parent}->pluck($ffar);

    } elsif($expand) {

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
    } elsif($anchor &&! $subs) {
      $anchor->pushlv($lv);
      $anchor=undef;

    # ^one-node sub-branch
    } else {

      ($anchor)=$branch->insert(
        $lv->{idex},(sprintf "\$%04X",$i++)

      );

      $anchor->pushlv($lv);
      $anchor=undef;

    };

  };

  $branch->sweep(qr{^,$});

};

# ---   *   ---   *   ---
# ^collapse

sub tree_solve($self,$branch) {

  my @pending=@{$branch->{leaves}};

  while(@pending) {

    my $lv   = shift @pending;
    my $idex = $lv->{idex};

    $lv->flatten_to_string(join_char=>$NULLSTR);

    # TODO: apply cdef expansion
    #       before recursing

    my @expr=$PE_OPS->recurse(

      $lv,

      mach       => $self->{mach},
      frame_vars => $self->Shared_FVars(),

    );

    $branch->pluck($lv);
    $branch->pushlv(@expr);

  };

};

# ---   *   ---   *   ---
# crux

sub recurse($class,$branch,%O) {

  my $s=(Tree::Grammar->is_valid($branch))
    ? $branch->{value}
    : $branch
    ;

  my $ice  = $class->new(%O);
  my @expr = $ice->expr_split($s);


  return map {
    eye->new($ARG->pluck_all())

  } @expr;

};

# ---   *   ---   *   ---
# get [names,values] from nterm

sub rd_nterm($self,$lv) {

  my @eye=$PE_EYE->recurse(

    $lv,

    mach       => $self->{mach},
    frame_vars => $self->Shared_FVars(),

  );


  return map {[$ARG->branch_values()]} @eye;

}

# ---   *   ---   *   ---
# ^shorthand for common pattern

sub rd_name_nterm($self,$branch) {

  my $lv    = $branch->{leaves};

  my $name  = $lv->[0]->leaf_value(0);
  my $nterm = $lv->[1]->{leaves}->[0];

  my @nterm = (defined $nterm)
    ? $self->rd_nterm($nterm)
    : ()
    ;

  return ($name,@nterm);

};

# ---   *   ---   *   ---
# ^slightly less common

sub rd_beg_nterm($self,$branch,$x) {

  my $lv    = $branch->{leaves};

  my @beg   = map {
    $lv->[$ARG]->leaf_value(0)

  } 0..$x-1;

  my $nterm = $lv->[1]->{leaves}->[0];

  my @nterm = (defined $nterm)
    ? $self->rd_nterm($nterm)
    : ()
    ;

  return (@beg,@nterm);

};

# ---   *   ---   *   ---
# do not generate a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# helper class

package eye;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::PM;

# ---   *   ---   *   ---
# inherits from

  submerge(

    [qw(Grammar::peso::ops)],

    xdeps=>1,
    subex=>qr{^throw_},

  );

# ---   *   ---   *   ---
# cstruc

sub new($class,@ar) {
  my $self=bless [@ar],$class;
  return $self;

};

# ---   *   ---   *   ---
# extract branch values from
# eye array

sub branch_values($self) {
  return map {$self->opvalue($ARG)} @$self;

};

# ---   *   ---   *   ---
# ^get raw of branch values

sub branch_values_raw($self) {
  return map {$ARG->get()} $self->branch_values();

};

# ---   *   ---   *   ---
# debug out

sub dbout($self) {
  map {$ARG->prich()} @$self;

};

# ---   *   ---   *   ---
1; # ret
