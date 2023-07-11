#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO COMMON
# A load of little things
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::common;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;
  use Grammar;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_COMMON);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    %{Grammar->Frame_Vars()},

    -passes => [

      '_ctx','_opz','_cl',
      '_pre','_ipret',

      '_run'

    ],

    -nest => {
      parens => 0,
      switch => 0,

    },

  }};

  Readonly our $PE_COMMON=>
    'Grammar::peso::common';

# ---   *   ---   *   ---
# GBL

BEGIN {

  our $REGEX={

    term  => Lang::nonscap(q[;]),
    clist => Lang::nonscap(q[,]),
    lcom  => Lang::eaf(q[\#]),

    nsop  => qr{::},

    nterm => Lang::nonscap(

      q[;],

      iv    => 1,
      mod   => '+',
      sigws => 1,

    ),

    tag   => Lang::delim_capt('<','>'),
    repl  => Lang::delim_capt('%'),

  };

# ---   *   ---   *   ---
# lets call these "syntax ops"

  rule('~?<clist> &rew');
  rule('~<term>');
  rule('~<lcom>');

# ---   *   ---   *   ---
# nterm: anything if its NOT a terminator

  rule('~<nterm>');
  rule('?<opt-nterm> &clip nterm');

# ---   *   ---   *   ---
# open/close

  rule('%<beg-curly=\{>');
  rule('%<end-curly=\}>');

  rule('%<beg-parens=\(> &erew');
  rule('%<end-parens=\)> &erew');

  rule('$?<fbeg-parens> &nest_parens beg-parens');
  rule('$?<fend-parens> &nest_parens end-parens');

# ---   *   ---   *   ---
# ^post-parse

sub nest_parens($self,$branch) {

  state $is_beg = qr{beg\-parens}x;

  # no match
  my $lv=$branch->{leaves}->[0];
  if(! @{$lv->{leaves}}) {
    Grammar::discard($self,$branch);
    return;

  };

  # ^its a trap
  my $f   = $self->{frame};
  my $top = \$f->{-nest}->{parens};

  # go up one recursion level
  if($branch->{value}=~ $is_beg) {
    $branch->{value}=$$top++;

  # ^mark end
  } else {
    $branch->{value}=--$$top . '<';

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^context pass

sub nest_parens_ctx($self,$branch) {

  state $re = qr{
    (?<num> \d+)
    (?<end> \< )?

  }x;

  my $f    = $self->{frame};
  my $nest = $f->{-nest}->{parens};

  $branch->{value}=~ $re;

  my $num=$+{num};
  my $end=$+{end};

  # get all nodes from beg+1 to end
  if(! defined $end) {

    my $pat=qr{$branch->{value} \<}x;

    my @lv=$branch->match_up_to($pat);

    # ^parent to beg
    $branch->pushlv(@lv);
    $branch->{value}="()";

  } else {
    $branch->{parent}->pluck($branch);

  };

};

# ---   *   ---   *   ---
# ^do not generate a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
