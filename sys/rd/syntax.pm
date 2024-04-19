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
  use Arstd::Re;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  opr => {

    binary => [qw(

      -> ->*

      & | ^ << >>

      *^ * / + -

      == != < <= >= > && ||

      &= |= ^= <<= >>=

      *^= *= /= += -=

    )],

    unary  => [qw(~ ? ! ++ --)],

  },

  list => [qw(csv join_opr)],

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
# match comma separated values

sub csv($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # single comma/anything BUT
  my $comma  = $l1->re(OPR  => ',');
  my $ncomma = $l1->re(WILD => '[^,]+');


  # give params
  return (

    'fwd-parse' => 'comma-list',


    re  => $ncomma,
    sig => [$comma,$ncomma],

    fn  => sub {


      # unpack
      my $self   = $_[0];
      my $branch = $_[1];
      my $data   = $_[2];


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

        $branch->{leaves}->[0]->{value}=$tmp;

      };


      # remove nesting
      map {
        $ARG->flatten_branch()

      } $branch->branches_in(
        $l1->re(LIST=>'.+'),
        inclusive=>0,

      );

      return 0;


    },

  );

};

# ---   *   ---   *   ---
# joins operators!

sub join_opr($self) {


  # get ctx
  my $main = $self->{main};
  my $l0   = $main->{l0};
  my $l1   = $main->{l1};


  # match any operator!
  my $chars = join null,@{$l0->spchars};
     $chars = "\Q$chars";

  my $opr   = $l1->re(OPR => "[$chars]+");

  # ^get valid combinations
  my $combo = re_eiths(
    $self->opr_list,
    opscape=>1,

  );


  # give params
  return (

    'fwd-parse' => 'join-opr',

    sig => [$opr],
    re  => $opr,

    fn  => sub {


      # unpack
      my $self   = $_[0];
      my $branch = $_[1];
      my $data   = $_[2];


      # join both operators
      my $token=$l1->cat(
        $branch->{value},
        $branch->leaf_value(0),

      );

      my $have=$l1->untag($token);


      # undo if combination is invalid
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

    },

  );

};

# ---   *   ---   *   ---
# sorts binary operations by precedence

sub sort_bopr($self) {

};

# ---   *   ---   *   ---
1; # ret
