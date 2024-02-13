#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:L1
# Token reader
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::l1;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Arstd::WLog;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $TAG=>qr{

    ^\[

    (?<type>  . )
    (?<value> .+)


    \]\s

  }x;

  # two-way hash
  Readonly my $TAG_T=>{ map {(

    $ARG->[0]=>$ARG->[1],
    $ARG->[1]=>$ARG->[0],

  )} (

    ['*' => 'OPERA'],
    ['%' => 'STRING'],
    ['i' => 'IDEX'],
    ['b' => 'BRANCH'],

  )};

# ---   *   ---   *   ---
# make tag regex

sub tagre($class,$type,$value) {
  return qr{^\[$type$value\]\s};

};

# ---   *   ---   *   ---
# turn current token into
# a tag of type

sub make_tag($class,$rd,$type,$src=undef) {

  # get/validate sigil
  my $tag_t=$TAG_T->{$type};

  $rd->perr(
    "invalid tag-type '%s'",
    args=>[$type],

  ) if ! defined $tag_t;

  $rd->perr(

    "'%s' is a byte-sized tag-type, reserved "
  . "for internal use only; "

  . "use '%s' instead",

    args => [$type,$tag_t],


  ) if 1 < length $tag_t;


  # give and forget?
  if(defined $src) {
    return "[$tag_t$src]";

  # ^nope, overwrite token
  } else {
    $rd->{token}="[$tag_t$rd->{token}] ";
    return $rd->{token};

  };

};

# ---   *   ---   *   ---
# joins the values of an array
# of tags of the same type
#
# gives a new tag holding all
# values joined together

sub cat_tags($class,$rd,@ar) {

  my $otype  = undef;
  my $ovalue = $NULLSTR;

  map {

    # disassemble tag
    my ($type,$value)=$class->read_tag(
      $rd,$ARG

    );


    # cat value to result
    $otype  //= $type;
    $ovalue  .= $value;

    # enforce equal types
    $rd->perr(
      "non-matching tag-types "
    . "cannot be catted!"

    ) if $type ne $otype;


  } @ar;


  # get non-internal type
  $otype=$TAG_T->{$otype};

  # make new and give
  return $class->make_tag($rd,$otype,$ovalue);

};

# ---   *   ---   *   ---
# token has [$tag] format?

sub read_tag($class,$rd,$src=undef) {

  $src //= $rd->{token};

  return ($src=~ $TAG)
    ? ($+{type},$+{value})
    : undef
    ;

};

# ---   *   ---   *   ---
# ^give tag type/value if correct type

sub read_tag_t($class,$rd,$which) {

  my ($type,$value)=$class->read_tag($rd);

  return ($type && $TAG_T->{$type} eq $which)
    ? $type
    : undef
    ;

};

sub read_tag_v($class,$rd,$which) {

  my ($type,$value)=$class->read_tag($rd);

  return ($type && $TAG_T->{$type} eq $which)
    ? $value
    : undef
    ;

};

# ---   *   ---   *   ---
# ^iceof

sub operator($class,$rd) {
  return $class->read_tag_v($rd,'OPERA');

};

# ---   *   ---   *   ---
1; # ret
