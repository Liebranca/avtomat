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

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $TAG=>qr{

    ^\[

    (?<type>  . )
    (?<value> .+)


    \]\s

  }x;

  Readonly my $TAG_T=>{

    '*' => 'OPERA',
    '%' => 'STRING',

  };

# ---   *   ---   *   ---
# token has [$tag] format?

sub read_tag($class,$rd) {

  return ($rd->{token}=~ $TAG)
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
