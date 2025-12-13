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

  use Arstd::String qw(cat gsplit);
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


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    macroload
    macrosave
    c_to_perl
    parse_as_label
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
  my @spec=gsplit($nd->{expr},qr{\s+});
  my $name=pop @spec;

  # redef guard
  throw "Redefinition of macro '$name'"
  if exists cmamdef()->{$name};

  # get specifiers
  my $valid = spec();
  my $type  = 0x0000;
  for(@spec) {
    throw "Invalid macro specifier '$ARG'"
    if ! exists $valid->{$ARG};

    $type |= $valid->{$ARG};
  };

  # make subroutine from source
  $nd->{expr} = $name;
  $nd->{cmd}  = 'sub';
  my $fnstr=c_to_perl($nd);

  # now put strings back in
  ctree()->unstrtok($fnstr);

  # generate and register new symbol
  macroload($name,$fnstr,$type);
  macrosave($name,$fnstr,$type);

  # defining a macro gives back nothing ;>
  %$nd=();
  return;
};


# ---   *   ---   *   ---
# list of valid specifiers for macros
#
# [*]: const

sub spec {
  return {
    # top level macros do not execute unless
    # they are the very first token in an
    # expression ($nd->{cmd})
    top      => 0x0001,

    # label macros are top level macros with
    # the added syntax of cmd args:expr
    label    => 0x0011,

    # internal macros will never be called
    # outside the body of *other* macros!
    internal => 0x0100,
  };
};


# ---   *   ---   *   ---
# doesn't actually translate, it just
# lets us use a C parser for a subset of perl

sub c_to_perl {
  for my $nd(@_) {
    # recurse for block
    my @blk=@{$nd->{blk}};
    c_to_perl(@blk);
  };

  # make string from all nodes
  my $out=ctree()->expr_to_code_impl(@_);

  # "dir :: pkg" should be "dir::pkg"...
  my $dcolon_re=qr{\s*::\s*};
  $out=~ s[$dcolon_re][::]g;

  return $out;
};


# ---   *   ---   *   ---
# makes/reloads definitions
#
# [0]: byte ptr  ; name of symbol
# [1]: byte ptr  ; symbol definition
# [2]: qword     ; flags
#
# [*]: writes to CMAMOUT

sub macrosave {
  push @{cmamout()->{def}},join("\n",
    "sub _$_[0]_spec {return $_[2]};",
    $_[1]
  );
  return;
};


# ---   *   ---   *   ---
# makes/reloads definitions
#
# [0]: byte ptr  ; name of symbol
# [1]: byte fptr ; symbol definition
#                  OR pointer to defined symbol
#
# [2]: qword ; flags
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
  cmamdef()->{$_[0]}={fn=>$fn,flg=>$_[2]};

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
# reads cmd param,param:expr,
#
# [<]: byte pptr ; every token before the `:` colon,
#                  separated as [cmd=>(param)]

sub parse_as_label {
  my ($nd) = @_;
  my $cmd  = $nd->{cmd};

  my ($param,@expr)=gsplit(
    $nd->{expr},
    qr" *:(?!:) *"
  );
  my (@param)=gsplit($param,qr" *, *");

  $nd->{expr} = join(":",@expr);
  $nd->{cmd}  = tokenshift($nd);

  return ($cmd,@param);
};


# ---   *   ---   *   ---
1; # ret
