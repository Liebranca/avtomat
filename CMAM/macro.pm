#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM MACRO
# pointed at your feet
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package CMAM::macro;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(
    is_null
    is_coderef
    is_hashref
    is_arrayref
  );

  use Arstd::String qw(cat);
  use Arstd::Token qw(
    tokenshift
    semipop
  );
  use Arstd::throw;
  use Tree::C;

  use lib "$ENV{ARPATH}/lib/";
  use CMAM::static qw(
    cmamdef
    cmamout
    cpackage
    ctree
  );
  use CMAM::emit;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    macroguard
    macroload
    macrosave
    macroin
    macrofoot
    c_to_perl
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# base of every CMAM definition
#
# [0]: mem ptr ; code block capture
# [<]: null
#
# [!]: adds an actual subroutine to CMAM package

sub macro {
  my ($nd)=@_;

  # redef guard
  throw "Redefinition of macro '$nd->{expr}'"
  if exists cmamdef()->{$nd->{expr}};

  # make subroutine from source
  $nd->{cmd}='sub';
  my $fnstr=c_to_perl($nd);

  # now put strings back in
  ctree()->unstrtok($fnstr);

  # generate and register new symbol
  macroload($nd->{expr},$fnstr);
  macrosave($fnstr);

  # defining a macro gives back nothing ;>
  %$nd=();
  return;
};


# ---   *   ---   *   ---
# doesn't actually translate, it just
# lets us use a C parser for a subset of perl

sub c_to_perl {
  my $sigil_re = qr{\s*(?<!\\)([\$\@])\s*};
  my $deref_re = qr{\s*\->$};
  my $semi_re  = qr{;$};

  for my $nd(@_) {
    $nd->{cmd}  =~ s[$sigil_re][$1]g;
    $nd->{expr} =~ s[$sigil_re][$1]g;

    if(is_arrayref($nd->{args})) {
      $ARG=~ s[$sigil_re][$1]g for @{$nd->{args}};
    } else {
      $nd->{args}=~ s[$sigil_re][$1]g;
    };

    # recurse for block
    my @blk=@{$nd->{blk}};
    c_to_perl(@blk);

    # ^ C parser iprets "$self->{...}->{...}"
    #   as a series of blocks, so undo that
    if(int(@blk)
    && ($nd->{expr}=~ s[$deref_re][->]g)) {
      my $s=Tree::C->expr_to_code_impl(@blk);
      $s=~ s[$semi_re][]g;
      $nd->{expr}   = "$nd->{expr}\{$s}";
      @{$nd->{blk}} = ();
    };
  };

  # make string from all nodes
  my $out=ctree()->expr_to_code_impl(@_);

  # ^ fix malformed expressions caused by the
  #   aforementioned "$self->{...}->{...}" issue
  my $join_re=qr{;\s+(?<opr>[^[:alnum:];\$\@\%\s\{\}]+)};
  while($out=~ $join_re) {
    my $opr   = $+{opr};
       $opr //= null;

    $out=~ s[$join_re][${opr}];
  };

  # "dir :: pkg" should be "dir::pkg"...
  my $dcolon_re=qr{\s*::\s*};
  $out=~ s[$dcolon_re][::]g;

  # ^regexes maan
  my $subex_re=qr{\bs \[([^\]]+) \]\[ ([^\]]+) \]};
  while($out=~ $subex_re) {
    my ($pat,$wat)=($1,$2);
    $pat//=null;
    $wat//=null;

    $out=~ s[$subex_re][s\[$pat\]\[$wat\]]g;
  };

  my $flgex_re=qr{([\]\}]) ([gsmx]+)};
  $out=~ s[$flgex_re][$1$2]g;
  return $out;
};


# ---   *   ---   *   ---
# makes/reloads definitions
#
# [0]: byte ptr ; symbol definition
#
# [*]: writes to CMAMOUT

sub macrosave {
  push @{cmamout()->{def}},$_[0];
  return;
};


# ---   *   ---   *   ---
# makes/reloads definitions
#
# [0]: byte ptr  ; name of symbol
# [1]: byte fptr ; symbol definition
#                  OR pointer to defined symbol
#
# [!]: makes an actual subroutine

sub macroload {
  # need to make definition?
  my $fn  = $_[1];
  my $def = ! is_coderef($fn);
  if($def) {
    my $re  = qr{^sub\s+[[:alnum:]_]+};

    $fn=~ s[$re][sub ];
    $fn=eval "package CMAM\::sandbox;$fn";
  };

  # ^catch compile error
  throw "Cannot define macro '$_[0]'\n"
  .     "Definition: $_[1]"

  if ! defined $fn;


  # add symbol to internal command table
  #
  # this allows the macro to be recognized
  # when invoked from C code
  cmamdef()->{$_[0]}=$fn;

  # add symbol to current package's subroutines
  #
  # this allows the macro to be invoked from
  # within another, as you would in regular perl
  if($def) {
    no strict 'refs';
    *{"CMAM\::sandbox\::$_[0]"}=$fn;

    use strict 'refs';
  };
  return;
};


# ---   *   ---   *   ---
# sets namespace for CMAM defs
#
# [!]: header guards are affected by this;
#      the __last__ package essentially gets
#      to name the guards -- so careful

sub setpkg {
  my ($nd)=@_;

  # 'non' just means global scope
  my $name=($nd->{expr} eq 'non')
    ? null
    : $nd->{expr}
    ;

  my $dcolon_re=qr{\s*::\s*};
  $name=~ s[$dcolon_re][::];
  cpackage($name);

  %$nd=();
  return;
};


# ---   *   ---   *   ---
1; # ret
