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
  use Arstd::Token qw(tokenshift semipop);
  use Arstd::Repl;
  use Arstd::throw;

  use Type qw(typefet);
  use Tree::C;
  use Ftype::Text::C;

  use lib "$ENV{ARPATH}/lib/";
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
  use CMAM::macro;


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
  my $tree = ctree($_[0]);
  my @expr = $tree->to_expr();
  my @out  = map {exprproc($ARG)} @expr;

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

  # proc commands within the expression itself,
  # excluding those marked as internal or top level
  my $def_re=cmamdef_re(
    CMAM::macro::spec()->{top}
  | CMAM::macro::spec()->{internal}
  );
  while($nd->{expr}=~ $def_re) {
    my $scmd=$+{scmd};
    my $prev=null;

    # shift tokens until we find the command
    while(! is_null($nd->{expr})) {
      my $s=tokenshift($nd);
      if($s ne $scmd) {
        # we save the tokens that are _behind_
        # the token for the command itself
        $prev .= is_null($prev) ? "$s" : " $s" ;

      # we know what the command is, so we
      # can safely discard this token
      } else {last};
    };

    # all tokens to the right of the command
    # are used as arguments...
    my ($snd)=ctree()->rd(
      "$scmd $nd->{expr}"

    )->to_expr();

    # ^execute it
    ($snd)=runcmd($snd);

    # restore shifted tokens and cat them
    # to whatever the command returns
    $nd->{expr}="$prev $snd->{expr}";

    # ^ get rid of whitespace
    #   JIC the command gave null
    strip($nd->{expr});
  };

  # proc top level commands, as they are excluded
  # from the previous loop
  push @out,runcmd($nd);
  return @out if ! %$nd;


  # check whether we're stepping into a block
  my @blk=@{$nd->{blk}};
  if(@blk) {
    # start a new scope if walking into a function
    set_local_scope($nd) if $nd->{type} eq 'proc';

    # recurse for block
    $nd->{blk}=[map {exprproc($ARG)} @blk];

    # terminate scope if we're inside a function
    unset_local_scope() if $nd->{type} eq 'proc';
  };

  if($nd->{type} eq 'asg') {
    CMAM::static::add_value_typedata($nd);
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

  # fetch command from node
  my @out = ();
  my $cmd = $nd->{cmd};
  my $def = (exists cmamdef()->{$cmd})
    ? cmamdef()->{$cmd}
    : null
    ;

  # run command, then recurse for each returned
  # node until there is nothing left to process
  if(! is_null($def)) {
    # check that its not an internal command
    my $forbid=CMAM::macro::spec()->{internal};
    throw "Illegal: internal command '$cmd' called "
    .     "outside of a macro"

    if $def->{flg} & $forbid;

    # ^and _then_ run ;>
    for my $ch($def->{fn}->($nd)) {
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
1; # ret
