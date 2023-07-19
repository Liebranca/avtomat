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

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  sub Frame_Vars($class) { return {

    %{Grammar->Frame_Vars()},

    -passes => [

      '_ctx','_ord',

      '_cl','_opz',
      '_pre','_ipret',

      '_run'

    ],

    -nest => {
      parens => 0,
      curly  => 0,
      brak   => 0,
      switch => 0,

    },

  }};

  Readonly our $PE_COMMON=>
    'Grammar::peso::common';

# ---   *   ---   *   ---
# GBL

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

# ---   *   ---   *   ---
# [^{]+ | [^}]+

    q[nbeg-curly] => Lang::nonscap(

      q[{],

      iv    => 1,
      mod   => '+',
      kls   => 1,
      sigws => 1,

      -x    => q[;],

    ),

    q[nend-curly] => Lang::nonscap(

      q[}],

      iv    => 1,
      mod   => '+',
      kls   => 1,
      sigws => 1,

      -x    => q[;],

    ),

    q[ncurly] => Lang::nonscap(

      q[{}],

      iv    => 1,
      mod   => '+',
      kls   => 1,
      sigws => 1,

      -x    => q[;],

    ),

# ---   *   ---   *   ---
# [^(]+ | [^)]+

    q[nbeg-parens] => Lang::nonscap(

      q[(],

      iv    => 1,
      mod   => '+',
      kls   => 1,
      sigws => 1,

      -x    => q[;],

    ),

    q[nend-parens] => Lang::nonscap(

      q[)],

      iv    => 1,
      mod   => '+',
      kls   => 1,
      sigws => 1,

      -x    => q[;],

    ),

    q[nparens] => Lang::nonscap(

      q[()],

      iv    => 1,
      mod   => '+',
      kls   => 1,
      sigws => 1,

      -x    => q[;],

    ),

# ---   *   ---   *   ---
# [^\[]+ | [^\]]+

    q[nbeg-brak] => Lang::nonscap(

      q{[},

      iv    => 1,
      mod   => '+',
      kls   => 1,
      sigws => 1,

      -x    => q[;],

    ),

    q[nend-brak] => Lang::nonscap(

      q{]},

      iv    => 1,
      mod   => '+',
      kls   => 1,
      sigws => 1,

      -x    => q[;],

    ),

    q[nbrak] => Lang::nonscap(

      q{[]},

      iv    => 1,
      mod   => '+',
      kls   => 1,
      sigws => 1,

      -x    => q[;],

    ),

# ---   *   ---   *   ---
# captures delimiter-enclosed terms

    q[sep-delim] => Lang::array_rec_delim(
      [['{','}'],['(',')'],['[',']']],
      capt=>1

    ),

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
# n[delim]: anything if its NOT [delimiter]

  rule('~<nbeg-curly>');
  rule('~<nend-curly>');
  rule('~<ncurly>');

  rule('$?<opt-nbeg-curly> &clip nbeg-curly');
  rule('$?<opt-nend-curly> &clip nend-curly');
  rule('$?<opt-ncurly> &clip ncurly');

  rule('~<nbeg-parens>');
  rule('~<nend-parens>');
  rule('~<nparens>');

  rule('$?<opt-nbeg-parens> &clip nbeg-parens');
  rule('$?<opt-nend-parens> &clip nend-parens');
  rule('$?<opt-parens> &clip nparens');

  rule('~<nbeg-brak>');
  rule('~<nend-brak>');
  rule('~<nbrak>');

  rule('$?<opt-nbeg-brak> &clip nbeg-brak');
  rule('$?<opt-nend-brak> &clip nend-brak');
  rule('$?<opt-brak> &clip nbrak');

# ---   *   ---   *   ---
# open/close

  rule('%<beg-curly=\{> &erew');
  rule('%<end-curly=\}> &erew');
  rule('%<beg-parens=\(> &erew');
  rule('%<end-parens=\)> &erew');
  rule('%<beg-brak=\[> &erew');
  rule('%<end-brak=\]> &erew');

  rule('$?<fbeg-parens> &nest_parens beg-parens');
  rule('$?<fend-parens> &nest_parens end-parens');
  rule('$?<fbeg-curly> &nest_curly beg-curly');
  rule('$?<fend-curly> &nest_curly end-curly');
  rule('$?<fbeg-brak> &nest_brak beg-brak');
  rule('$?<fend-brak> &nest_brak end-brak');

# ---   *   ---   *   ---
# ^post parse

sub nest_delim($self,$branch,$key,$is_beg) {

  # leaves of branch's leaves
  my @lv=map {
    @{$ARG->{leaves}}

  } @{$branch->{leaves}};

  # no match
  if(! @lv) {
    Grammar::discard($self,$branch);
    return 0;

  };

  my $f   = $self->{frame};
  my $top = \$f->{-nest}->{$key};

  # go up one recursion level
  if($branch->{value}=~ $is_beg) {
    $branch->{value}=$$top;
    $$top+=@lv

  # ^mark end
  } else {
    $$top-=@lv;
    $branch->{value}=$$top . '<';

  };

  $branch->{is_delim}=$key;

  return 1;

};

# ---   *   ---   *   ---
# ^context pass

sub nest_delim_ctx($self,$branch,$key,$repl) {

  state $re = qr{
    (?<num> \d+)
    (?<end> \< )?

  }x;

  my $f    = $self->{frame};
  my $nest = $f->{-nest}->{$key};

  $branch->{value}=~ $re;

  my $num=$+{num};
  my $end=$+{end};

  # get all nodes from beg+1 to end
  if(! defined $end) {

    my $pat = qr{$branch->{value} \<}x;
    my @lv  = $branch->match_up_to($pat);

    # ^parent to beg
    $branch->pushlv(@lv);
    $branch->{value}=$repl;

  } else {
    $branch->{parent}->pluck($branch);

  };

};

# ---   *   ---   *   ---
# ^curly ice

sub nest_curly($self,$branch) {

  state $is_beg = qr{beg\-curly}x;
  return if ! $self->nest_delim(
    $branch,'curly',$is_beg

  );

  $branch->clear();

};

sub nest_curly_ctx($self,$branch) {
  $self->nest_delim_ctx($branch,'curly','{}');

};

# ---   *   ---   *   ---
# ^parens ice

sub nest_parens($self,$branch) {

  state $is_beg = qr{beg\-parens}x;
  return if ! $self->nest_delim(
    $branch,'parens',$is_beg

  );

  $branch->clear();

};

sub nest_parens_ctx($self,$branch) {
  $self->nest_delim_ctx($branch,'parens','()');

};

# ---   *   ---   *   ---
# ^brak ice

sub nest_brak($self,$branch) {

  state $is_beg = qr{beg\-brak}x;
  return if ! $self->nest_delim(
    $branch,'brak',$is_beg

  );

  $branch->clear();

};

sub nest_brak_ctx($self,$branch) {
  $self->nest_delim_ctx($branch,'brak','[]');

};

# ---   *   ---   *   ---
# ^do not generate a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
