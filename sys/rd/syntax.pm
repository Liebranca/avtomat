#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:SYNTAX
# Method icef++k!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::syntax;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::Re;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  opr => {

    binary => [qw(

      -> ->*

      & | ^ << >>

      *^ / * + -

      == != < <= >= > && ||

      &= |= ^= <<= >>=

      *^= *= /= += -=

    )],

    unary  => [qw(~ ? ! ++ --)],

  },

  csv_char => '\,',

  list     => [qw(

    csv
    join_opr

  )],

};

# ---   *   ---   *   ---
# get list of all operators

sub opr_list($self) {

  return [

    @{$self->opr->{binary}},
    @{$self->opr->{unary}},

  ];

};

# ---   *   ---   *   ---
# ^get list of operator chars!

sub opr_charset($self) {

  state $out=undef;
  return $out if $out;

  my $chars=join  null,@{$self->opr_list};
  my @chars=split null,$chars;

  array_dupop \@chars;

  $out=\@chars;
  return $out;

};

# ---   *   ---   *   ---
# ^get regex for valid combinations

sub opr_combo($self) {

  state $out=undef;
  return $out if $out;

  $out=re_eiths(
    $self->opr_list,
    opscape=>1,

  );

  return $out;

};

# ---   *   ---   *   ---
# ^binary

sub bopr_combo($self) {

  state $out=undef;
  return $out if $out;

  $out=re_eiths(
    $self->opr->{binary},
    opscape=>1,

  );

  return $out;

};

# ---   *   ---   *   ---
# makes L2 definitions

sub build($self) {

  # get ctx
  my $main = $self->{main};
  my $l2   = $main->{l2};

  # subs in this package act as params to
  # an l2 method definition
  #
  # so: get list of such subs and pass them!

  map {$l2->define($self->$ARG)}
  @{$self->list};

  return;

};

# ---   *   ---   *   ---
# entry point

sub apply_rules($self,$branch) {


  # get ctx
  my $main = $self->{main};
  my $l2   = $main->{l2};


  # exec rules:
  #
  # * join composite operators
  # * sort operations
  #
  # * join comma-separated lists

  $l2->invoke('fwd-parse'=>'join-opr')
  if ! @{$branch->{leaves}};

  $self->make_ops($branch);
  $l2->invoke('fwd-parse'=>'csv');


  return;

};

# ---   *   ---   *   ---
# match comma separated values

sub csv($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # single comma/anything BUT
  my $char   = $self->csv_char;

  my $comma  = $l1->re(OPR  => $char);
  my $ncomma = $l1->re(WILD => "[^$char]+");


  # give params
  return (

    'fwd-parse' => 'csv',


    re   => $ncomma,
    sig  => [$comma,$ncomma],

    fn   => \&_csv,
    flat => 1,

  );

};

# ---   *   ---   *   ---
# ^implementation

sub _csv($self,$branch,$data) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # single comma/anything BUT
  my $char   = $self->csv_char;

  my $comma  = $l1->re(OPR  => $char);
  my $ncomma = $l1->re(WILD => "[^$char]+");


  # merging lists?
  my $top=$l1->xlate($branch->{value});
  if($top && $top->{type} eq 'LIST') {

    $branch->pluck(
      $branch->branches_in($comma)

    );


  # ^nope!
  } else {

    my $tmp=$branch->{value};

    $branch->{value}=
      $l1->tag(LIST=>'csv');

    my $have=$branch->branch_in($comma);

    $branch->insert(0,$tmp);
    $have->discard();

  };


  # remove nesting
  map {
    $ARG->flatten_branch()

  } $branch->branches_in(
    $l1->re(LIST=>'.+'),
    inclusive=>0,

  );

  return 0;


};

# ---   *   ---   *   ---
# joins operators!

sub join_opr($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # match any operator!
  my $chars = join null,@{$self->opr_charset};
     $chars = "\Q$chars";

  my $opr   = $l1->re(OPR => "[$chars]+");


  # give params
  return (

    'fwd-parse' => 'join-opr',

    sig  => [$opr],
    re   => $opr,

    fn   => \&_join_opr,
    flat => 0,

  );

};

# ---   *   ---   *   ---
# ^implementation

sub _join_opr($self,$branch,$data) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # join both operators
  my $leafv=$branch->leaf_value(0);
  my $token=$l1->cat(
    $branch->{value},
    $leafv,

  );

  my $have=$l1->untag($token);


  # undo if combination is invalid
  my $combo=$self->opr_combo;
  if(! ($have->{spec}=~ m[^$combo$])) {

    $branch->flatten_branch(
      inclusive=>1

    );

    return '-x';


  # ^valid, replace and clear
  } else {

    $branch->{value}=$token;
    $branch->clear();

    return 0;

  };

};

# ---   *   ---   *   ---
# give list of operators nodes
# in tree, sorted by priority

sub sort_opr($self,$branch,$ar) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # match valid operators
  my $opr = re_eiths($ar,opscape=>1);


  # get operators by priority
  my @sorted=();
  map {

    my $x=$ARG->{value};
       $x=$l1->untag($x);

    $x=array_iof $ar,$x->{spec};

    if(defined $x) {
      $sorted[$x] //= [];
      push @{$sorted[$x]},$ARG;

    };

  } $branch->branches_in(
    qr{^\[\`$opr},
    max_depth=>0x01,

  );

  @sorted=grep {$ARG} @sorted;
  @sorted=array_flatten \@sorted,dupop=>1;

  @sorted=grep {! @{$ARG->{leaves}}} @sorted;

  return @sorted;

};

# ---   *   ---   *   ---
# sort unary operators

sub sort_uopr($self,$branch) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # get valid chars
  my $csv   = $self->csv_char;
  my $valid = $l1->re(WILD => "[^$csv]+");
  my $bopr  = $self->bopr_combo;
     $bopr  = qr{^\[\`$bopr};


  # walk
  map {

    my $idex = $ARG->{idex};
    my $par  = $ARG->{parent};
    my $lv   = $par->{leaves};

    my $have = undef;


    if($idex < @$lv-1
    &&! ($lv->[$idex+1]->{value}=~ $bopr)) {
      $have=$lv->[$idex+1];

    } elsif(0 < $idex
    &&! ($lv->[$idex-1]->{value}=~ $bopr)) {
      $have=$lv->[$idex-1]

    };

    $ARG->pushlv($have)

    if $have
    && ($have->{value}=~ $valid);


  } $self->sort_opr(
    $branch,$self->opr->{unary}

  );


  return;

};

# ---   *   ---   *   ---
# sort binary operators

sub sort_bopr($self,$branch) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # get valid chars
  my $csv   = $self->csv_char;
  my $valid = $l1->re(WILD => "[^$csv]+");


  # walk
  map {

    my $idex = $ARG->{idex};
    my $par  = $ARG->{parent};
    my $lv   = $par->{leaves};

    if(1 <= $idex && $idex < @$lv-1) {

      my @have=(
        $lv->[$idex-1],
        $lv->[$idex+1],

      );

      $ARG->pushlv(@have)

      if @have == int grep {
        $ARG->{value}=~ $valid

      } @have;

    };

  } $self->sort_opr(
    $branch,$self->opr->{binary}

  );

  return;

};

# ---   *   ---   *   ---
# sort all!

sub make_ops($self,$branch) {

  $self->sort_uopr($branch);
  $self->sort_bopr($branch);

  return;

};

# ---   *   ---   *   ---
1; # ret
