#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM PARSE
# dont do this!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package CMAM::parse;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(
    is_null
    is_arrayref
  );

  use Arstd::String qw(
    strip
    gstrip
    gsplit
    has_suffix
  );
  use Arstd::Repl;
  use Arstd::throw;

  use Type qw(typefet);
  use Tree::C;
  use Ftype::Text::C;

  use lib "$ENV{ARPATH}/lib/";
  use CMAM::token qw(tokenshift semipop);
  use CMAM::token qw(tokenshift semipop);
  use CMAM::static qw(
    cmamout
    cmamdef
    cmamdef_re
    cmamlol
    cmamgbl
    ctree

    is_local_scope
    set_local_scope
    unset_local_scope
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    blkparse
    type2expr
    blk2expr
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.9a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# block parser
#
# [0]: byte ptr ; code string
# [<]: bool     ; string is not null
#
# [!]: overwrites input string

sub blkparse {
  my $tree  = ctree($_[0]);
  my @expr  = $tree->to_expr();
  my @out   = map {exprproc($ARG)} @expr;

  return $tree->expr_to_code(@out);
};


# ---   *   ---   *   ---
# processes expression
#
# [0]: mem ptr ; expression hashref
# [<]: mem ptr ; modified copy (new array)
#
# [*]: a single expression may output multiple ones

sub exprproc {
  my ($nd) = @_;
  my @out  = ();

  # proc commands within expression itself
  my $def_re=cmamdef_re();
  while($nd->{expr}=~ $def_re) {
    my $scmd=$+{scmd};
    my $prev=null;

    while(! is_null($nd->{expr})) {
      my $s=tokenshift($nd);
      if($s ne $scmd) {
        $prev .= is_null($prev) ? "$s" : " $s" ;

      } else {last};
    };
    my ($snd)=ctree()->rd(
      "$scmd $nd->{expr}"

    )->to_expr();

    ($snd)=runcmd($snd);
    $nd->{expr}="$prev $snd->{expr}";
  };

  # proc top level commands
  push @out,runcmd($nd);
  return @out if ! %$nd;


  # check whether we're inside a function
  my @blk=@{$nd->{blk}};
  if(@blk) {
    if($nd->{type} eq 'proc') {
      # if so, start a new scope
      set_local_scope();
      %{cmamlol()}=();

      # ^and add function args to scope
      add_value_typedata(
        Tree::C->rd($ARG)->to_expr()

      ) for @{$nd->{args}};
    };

    # recurse for block
    $nd->{blk}=[map {exprproc($ARG)} @blk];

    # terminate scope if we're inside a function
    unset_local_scope()
    if $nd->{type} eq 'proc';
  };

  if($nd->{type} eq 'asg') {
    add_value_typedata($nd);
  };

  return @out;
};


# ---   *   ---   *   ---
# executes command found in expression
#
# [0]: mem ptr ; expression hashref
# [<]: mem ptr ; expanded expression (new array)

sub runcmd {
  my ($nd)=@_;
  return () if ! %$nd;

  my @out = ();
  my $cmd = $nd->{cmd};
  my $fn  = cmamdef()->{$cmd};

  # run command, then recurse for each returned
  # node until there is nothing left to process
  if(! is_null($fn)) {
    for my $ch($fn->($nd)) {
      if($ch->{cmd} ne $cmd) {
        push @out,exprproc($ch);
      } else {
        push @out,$ch;
      };
    };

  # no command just means give asis
  } else {
    push @out,$nd;
  };

  # empty node means command consumed input!
  return @out;
};


# ---   *   ---   *   ---
# add value typedata to current scope
#
# [0]: mem ptr ; expression hashref

sub add_value_typedata {
  my ($nd)=@_;

  # first, get the entire expression and
  # split it at the assignment part if any
  my $full     = "$nd->{cmd} $nd->{expr}";
  my $asg_re   = qr{[\s\d\w](=[^=].+)};
  my ($lh,@rh) = gsplit($full,$asg_re);

  # we don't actually use the right-hand side
  # right now, but we _may_ do so later
  #
  # anyway, convert the left-hand side to an
  # array so we can check whether this is
  # a value declaration
  type2expr($lh);
  my $name=pop @$lh;
  my $type=join ' ',grep {
    ! ($ARG=~ spec_t())

  } @$lh;

  # is the joined string in the type-table?
  if( Type->is_valid($type)
  &&! Type->is_base_ptr($type)) {
    # what scope are we in?
    my $scope=(is_local_scope())
      ? cmamlol()
      : cmamgbl()
      ;

    # record typedata about this value
    $scope->{$name}=$type;
  };
  return;
};


# ---   *   ---   *   ---
# pattern for matching specifiers
#
# [*]: const
# [<]: re

sub spec_t {
  return qr{(?:
    IX | CX | CIX | static | inline
  )};
};


# ---   *   ---   *   ---
# turns type specifiers into array
#
# [0]: byte ptr ; type specifiers (string)
# [!]: overwrites input string

sub type2expr {
  my @type=gsplit($_[0]);
  push @type,'void' if ! @type;

  $_[0]=\@type;

  return;
};


# ---   *   ---   *   ---
# turns a code block into an array
# of expressions
#
# [0]: byte ptr ; code block
# [!]: overwrites input string

sub blk2expr {
  my $curly_re=qr{(?:
    (?:^\s*\{\s*)
  | (?:\s*\}\s*;?\s*$)

  )}smx;
  $_[0]=~ s[$curly_re][]g;

  my $join_re=qr{\s*\\\n\s*}sm;
  $_[0]=~ s[$join_re][ ]g;

  my $expr_re=qr{([^\n;]+)\s*;\s*\n}sm;
  my $semi_re=qr{\s*;\s*$};
  $_[0]=[map {
    $ARG .= ';' if ! has_suffix($ARG,';');
    $ARG;
  } gsplit($_[0],$expr_re)];

  return;
};


# ---   *   ---   *   ---
1; # ret
