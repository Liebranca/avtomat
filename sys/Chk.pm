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

  use English;
  use Scalar::Util qw(blessed);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    nref

    is_blessref
    is_hashref
    is_coderef
    is_arrayref
    is_qre
    is_qreref

    is_scalarref
    is_filepath

    codefind

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# type-checking

sub is_scalarref ($v) {
  return defined $v && ('SCALAR' eq ref $v);

};

sub is_arrayref ($v) {
  return length ref $v && ('ARRAY' eq ref $v);

};

sub is_hashref ($v) {
  return length ref $v && ('HASH' eq ref $v);

};

sub is_blessref ($v) {
  return defined $v && defined blessed $v;

};

sub is_coderef ($v) {

  return (
     defined    $v
  && length ref $v

  && ('CODE' eq ref $v)

  );

};

sub is_qre ($v) {
  return defined $v && ('Regexp' eq ref $v);

};

sub is_qreref($v) {
  return is_scalarref($v) && is_qre($$v);

};

# ---   *   ---   *   ---
# value is just... nothing special

sub nref($v) {

  return (

      defined $v

  &&! is_scalarref($v)
  &&! is_arrayref($v)
  &&! is_hashref($v)
  &&! is_blessref($v)
  &&! is_coderef($v)
  &&! is_qre($v)

  );

};


# ---   *   ---   *   ---
# gets subroutine by name

sub getsub(@path) {

  state $re=qr{^(?<codename>[_\w:][_\w:\d]+)$}x;

  no strict 'refs';
  my $name = (join q[::],@path);
  my $fn   = ($name=~ $re)
    ? eval "\&$name"
    : undef
    ;


  return (is_coderef($fn) && defined &{$fn})
    ? $fn
    : undef
    ;

};


# ---   *   ---   *   ---
# evals and checks existence of sub
#
# performs deep search on failure

sub codefind(@path) {
  my $fn=getsub @path;
  return (! defined $fn)
    ? __isa_search(@path)
    : $fn
    ;

};


# ---   *   ---   *   ---
# ^searches inherited methods
# before giving up on coderef
#
# sometimes it happens ;>

sub __isa_search(@path) {

  my $name = pop @path;
  my $pkg  = join q[::],@path;

  no strict 'refs';
  my @isa=@{"$pkg\::ISA"};

  map {
    my $fn=getsub $ARG,$name;
    return $fn if defined $fn;

  } @isa;


  return undef;

};


# ---   *   ---   *   ---
# AR/approved filepath validate

sub is_filepath($fpath) {

  my $have=(

  !   ($fpath=~ $NEWLINE_RE)

  &&  (256 > length $fpath)
  &&  (-f $fpath)

  );

  return int(defined $have && $have);

};


# ---   *   ---   *   ---
# get value is a scalar or
# code reference
#
# if so, conditionally dereference

sub cderef($x,$deref,@args) {


  # have reference?
  my $isref  =
     (1 * int is_coderef   $x)
  || (2 * int is_scalarref $x);


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
