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

  csv_char => '\,',
  list     => [qw(csv join_opr make_opr)],

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
  my $char   = $self->csv_char;

  my $comma  = $l1->re(OPR  => $char);
  my $ncomma = $l1->re(WILD => "[^$char]+");


  # give params
  return (

    'fwd-parse' => 'csv',


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
  my $l1   = $main->{l1};


  # match any operator!
  my $chars = join null,@{$self->opr_charset};
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

      # validate input
      my $leafv=$branch->leaf_value(0);

      return '-x'
      if ! $l1->typechk(OPR=>$leafv);


      # join both operators
      my $token=$l1->cat(
        $branch->{value},
        $leafv,

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
# joins operator with operands!

sub make_opr($self) {


  # get ctx
  my $main = $self->{main};
  my $l0   = $main->{l0};
  my $l1   = $main->{l1};


  # match valid operators
  my $opr = re_eiths(
    $self->opr_list,
    opscape=>1,

  );

  my $csv = $self->csv_char;
  my $any = $l1->re(WILD => "[^$csv]+");


  # give params
  return (

    'fwd-parse' => 'make-opr',

    sig => [$opr,$any],
    re  => $any,

    fn  => \&_make_opr,

  );

};

# ---   *   ---   *   ---
# ^implementation

sub _make_opr($self,$branch,$data) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my @lv   = @{$branch->{leaves}};


  # validate
  if(@lv > 2) {

    $branch->{parent}->insertlv(
      $branch->{idex},
      @lv[2..$#lv]

    );

    return '-x';

  };


  # walk operands and typecheck'em
  my $out=0;

  map {

    my $top=$l1->xlate($branch->{value});
    my $bot=$l1->xlate($ARG->{value});


    # operand is an operator?
    if($bot && $bot->{type} eq 'OPR') {


      # swap operand and operator if the
      # root is *not* an operator

      if($top && $top->{type} ne 'OPR') {
        $branch->vcastle(src=>$ARG->{idex});


      # ^or move an empty operator tree!
      } else {

        $branch->{parent}->insertlv(
          $branch->{idex}+1,
          $ARG

        );

        $out='-x';

      };

    };


  } @lv;


  return $out;

};

# ---   *   ---   *   ---
# scratch!

#    my $token = $l1->xlate($nd->{value});
#
#    if($token && $token->{type} eq 'OPR') {
#
#      # we need to move the trees around
#      # so that sort-ops can see the
#      # sequence of operations!
#      #
#      # so: we leave a "note" saying
#      # this tree used to be here
#      #
#      # what we'll then do is use the note
#      # to find this tree when we start
#      # sorting by operator priority
#
#      my $ptr  = $l1->tag(NODE=>$nd->{-uid});
#         $ptr .= $nd->{value};
#
#      $branch->{parent}->insertlv(
#        $branch->{idex}+1,$nd
#
#      );
#
#      $branch->insert($first,$ptr);
#      $out='-x';
#
#    };

# ---   *   ---   *   ---
1; # ret
