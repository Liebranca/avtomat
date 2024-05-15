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
# lyeb,

# ---   *   ---   *   ---
# deps

package Chk;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Scalar::Util qw(blessed);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

#  use lib $ENV{'ARPATH'}.'/lib/hacks/';
#  use Inlining;

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

    stripline
    codefind

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.7;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $SCALARREF_RE=>qr{
    ^(?: SCALAR|REF) \(0x[0-9a-f]+\)

  }x;

  Readonly our $ARRAYREF_RE=>qr{
    ^ARRAY\(0x[0-9a-f]+\)

  }x;

  Readonly our $CODEREF_RE=>qr{
    ^CODE\(0x[0-9a-f]+\)

  }x;

  Readonly our $HASHREF_RE=>qr{
    ^HASH\(0x[0-9a-f]+\)

  }x;

  Readonly our $STRIPLINE_RE=>qr{\s+|:__NL__:}x;
  Readonly our $CODENAME_RE=>qr{
    ^ (?<codename> [_\w:][_\w:\d]+) $

  }x;

# ---   *   ---   *   ---
# type-checking

sub is_scalarref ($v) {
  defined $v && ($v=~ $Chk::SCALARREF_RE);

};

sub is_arrayref ($v) {
  length ref $v && ($v=~ $Chk::ARRAYREF_RE);

};

sub is_hashref ($v) {
  length ref $v && ($v=~ $Chk::HASHREF_RE);

};

sub is_blessref ($v) {
  defined $v && defined blessed $v;

};

sub is_coderef ($v) {

     defined    $v
  && length ref $v

  && ($v=~ $Chk::CODEREF_RE);

};

sub is_qre ($v) {
  defined $v && 'Regexp' eq ref $v;

};

sub is_qreref($v) {
  return is_scalarref($v) && is_qre($$v);

};

# ---   *   ---   *   ---
# value is just... nothing special

sub nref($v) {

      defined $v

  &&! is_scalarref($v)
  &&! is_arrayref($v)
  &&! is_hashref($v)
  &&! is_blessref($v)
  &&! is_coderef($v)
  &&! is_qre($v)
  ;

};

# ---   *   ---   *   ---
# remove all whitespace

sub stripline ($s) {
  join $NULLSTR,(split $Chk::STRIPLINE_RE,$s);

};

# ---   *   ---   *   ---
# evals and checks existance of sub

sub codefind(@names) {

  no strict 'refs';

  my $path  = (join q[::],@names);
  my $f     = ($path=~ $CODENAME_RE)
    ? eval '\&'.$path
    : undef
    ;

  my $valid =
     is_coderef($f)
  && defined &{$f}
  ;

  # deep search on failure
  ($valid,$f)=__isa_search(@names) if ! $valid;
  return ($valid) ? $f : undef;

};

# ---   *   ---   *   ---
# ^searches inherited methods
# before giving up on coderef
#
# sometimes it happens ;>

sub __isa_search(@names) {

  no strict 'refs';

  my @out = ();

  my $fn  = pop @names;
  my $pkg = join q[::],@names;

  my @isa=@{"$pkg\::ISA"};

  for my $class(@isa) {

    my $path  = "$class\::$fn";
    my $f     = ($path=~ $CODENAME_RE)
      ? eval '\&'.$path
      : undef
      ;

    my $valid =
       is_coderef($f)
    && defined &{$f}
    ;

    if($valid) {
      @out=(1,$f);
      last;

    };

  };

  return @out;

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
