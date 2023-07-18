#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO ARRAY
# Contiguous mem
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::array;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::String;
  use Arstd::IO;
  use Arstd::PM;

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
  our @EXPORT=qw($PE_ARRAY);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $PE_ARRAY=>
    'Grammar::peso::array';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # inherits from
  submerge(

    [qw(
      Grammar::peso::common
      Grammar::peso::value
      Grammar::peso::ops

    )],

    xdeps=>1,
    subex=>qr{^throw_},

  );

# ---   *   ---   *   ---
# class attrs

  sub Frame_Vars($class) { return {
    %{$PE_COMMON->Frame_Vars()},

  }};

# ---   *   ---   *   ---
# GBL

  our $REGEX={
    %{$PE_COMMON->get_retab()},

  };

# ---   *   ---   *   ---
# rule imports

  ext_rules(

    $PE_COMMON,qw(

    beg-brak end-brak
    fbeg-brak fend-brak

  ));

  ext_rules($PE_VALUE,qw(value));
  ext_rules($PE_OPS,qw(expr));

# ---   *   ---   *   ---
# [idex] notation

  rule(q[

    $<subscript>

    fbeg-brak
    expr

    fend-brak

  ]);

  rule('$?<opt-subscript> &clip subscript');

# ---   *   ---   *   ---
# ^post-parse

sub subscript($self,$branch) {

  state $delim = qr{^\d\<?$}x;
  state $brak  = qr{^\[\]$}x;

  # solve all delimiter branches
  map {
    $self->nest_brak_ctx($ARG)

  # ^for each matching condition
  } grep {
    $ARG->{is_delim} eq 'brak'

  } $branch->branches_in($delim);

  # ^flatten
  map {
    $ARG->flatten_branch();

  } $branch->branches_in($brak);

};

# ---   *   ---   *   ---
# ^subscript on value

  rule(q[

    $<value-subscript>
    &value_subscript

    value subscript

  ]);

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(value-subscript);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# test

$PE_OPS->parse(q{

  1 * name[0]

})->{p3}->prich();

# ---   *   ---   *   ---
