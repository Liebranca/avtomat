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

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

#  use lib $ENV{'ARPATH'}.'/lib/hacks/';
#  use Inlining;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    is_blessref
    is_hashref
    is_coderef
    is_arrayref
    is_qre
    is_qreref

    is_scalarref

    stripline
    codefind

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.4;#a
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

  Readonly our $BLESSREF_RE=>qr{

    (?: [_\w][_\w\d:])+

    =

    [\s\S]*

    \(0x[0-9a-f]+\)$

  }x;

  Readonly our $QRE_RE=>qr{\(\?\^u(?:[xsmg]*):}x;
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
  length ref $v && ($v=~ $Chk::BLESSREF_RE);

};

sub is_coderef ($v) {
  length ref $v && ($v=~ $Chk::CODEREF_RE);

};

sub is_qre ($v) {
  defined $v && ($v=~ $Chk::QRE_RE);

};

sub is_qreref($v) {
  return is_scalarref($v) && is_qre($$v);

};

# ---   *   ---   *   ---
# ^WIP

sub is_str($v) {

     defined $v

  && !is_scalarref($v)
  && !is_arrayref($v)
  && !is_hashref($v)
  && !is_blessref($v)
  && !is_coderef($v)
  && !is_qre($v)
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
1; # ret
