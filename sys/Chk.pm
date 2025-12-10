#!/usr/bin/perl
# ---   *   ---   *   ---
# CHECK
# Common conditionals
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Chk;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Scalar::Util qw(blessed);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    is_nref
    is_null
    is_blessref
    is_hashref
    is_coderef
    is_arrayref
    is_qre
    is_qreref
    is_scalarref
    is_path
    is_rpath
    is_file
    is_dir
    codefind
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# not a value!
#
# [0]: ptr  ; have
# [<]: bool ; true if not a value

sub is_null {
  return ! (defined $_[0] && length $_[0]);
};


# ---   *   ---   *   ---
# type-checking
#
# [0]: byte ptr ; value
# [<]: bool     ; true if value is type

sub is_scalarref {
  return ! is_null($_[0]) && 'SCALAR' eq ref $_[0];
};

sub is_arrayref {
  return ! is_null($_[0]) && 'ARRAY' eq ref $_[0];
};

sub is_hashref {
  return ! is_null($_[0]) && 'HASH' eq ref $_[0];
};

sub is_blessref {
  return ! is_null($_[0]) && defined blessed $_[0];
};

sub is_coderef {
  return ! is_null($_[0]) && 'CODE' eq ref $_[0];
};

sub is_qre {
  return ! is_null($_[0]) && 'Regexp' eq ref $_[0];
};

sub is_qreref {
  return is_scalarref($_[0]) && is_qre(${$_[0]});
};


# ---   *   ---   *   ---
# value is just... nothing special
#
# [0]: byte ptr ; value
# [<]: bool     ; true if non-null && non-ref

sub is_nref {
  return (
    ! is_null      ($_[0])
  &&! is_scalarref ($_[0])
  &&! is_arrayref  ($_[0])
  &&! is_hashref   ($_[0])
  &&! is_blessref  ($_[0])
  &&! is_coderef   ($_[0])
  &&! is_qre       ($_[0])
  );
};


# ---   *   ---   *   ---
# gets subroutine by name
#
# [0]: byte pptr ; path to subroutine
# [<]: fptr      ; subroutine || null

sub getsub {
  state $re=qr{^(?<codename>[_\w:][_\w:\d]+)$}x;

  no strict 'refs';
  my $name = join q[::],@_;
  my $fn   = ($name=~ $re)
    ? eval '\&' . $name
    : null
    ;

  return (is_coderef($fn) && defined &{$fn})
    ? $fn
    : null
    ;
};


# ---   *   ---   *   ---
# evals and checks existence of sub
#
# [0]: byte pptr ; path to subroutine
# [<]: fptr      ; subroutine || null
#
# [!]: performs deep search on failure

sub codefind {
  my $fn=getsub @_;
  return (is_null $fn)
    ? __isa_search(@_)
    : $fn
    ;
};


# ---   *   ---   *   ---
# ^searches inherited methods
# ^before giving up on coderef
#
# sometimes it happens ;>
#
# [0]: byte pptr ; path to subroutine
# [<]: fptr      ; subroutine || null

sub __isa_search {
  my $name = pop;
  my $pkg  = join q[::],@_;

  # give F if found
  no strict 'refs';
  for(@{"$pkg\::ISA"}) {
    my $fn=getsub($ARG,$name);
    return $fn if ! is_null $fn;
  };

  # give null on fail
  use strict 'refs';
  return null;
};


# ---   *   ---   *   ---
# AR/approved path validation
#
# [0] byte ptr ; path
# [<] bool     ; path is valid

sub path_chars {
  return qr{
    [/_A-Za-z\.\~]
    [/_A-Za-z0-9\-\.\:\@\%\$\&]*
  }x;
};

sub is_path {
  my $re=path_chars;
  return int(
   ! (is_null $_[0])

  && ($_[0]=~ qr{^$re$})
  && (1024 >= length $_[0])
  );
};

sub is_rpath {
  return is_path($_[0]) && -e $_[0];
};

sub is_file {
  return is_path($_[0]) && -f $_[0];
};

sub is_dir {
  return is_path($_[0]) && -d $_[0];
};


# ---   *   ---   *   ---
# TODO: move this somewhere else
#
# get value is a scalar or
# code reference
#
# if so, conditionally dereference

sub cderef($x,$deref,@args) {
  # have reference?
  my $isref=(
     (1 * int is_coderef   $x)
  || (2 * int is_scalarref $x)
  );

  if($deref && $isref) {
    my @out=($isref == 1)
      ? ($x->(@args))
      : ($$x)
      ;
    return ($isref,@out);
  };
  return $isref,$x;
};


# ---   *   ---   *   ---
1; # ret
