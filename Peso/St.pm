#!/usr/bin/perl
# ---   *   ---   *   ---
# ST
# Fundamental peso structures
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Peso::St;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $TYPE_BLOCK=>0x01;

# ---   *   ---   *   ---
# constructor for pkg hash

sub getout($type) {

  my %out=(
    type=>$type,

    header=>{},
    data=>[],

  );

  return $out{header},$out{data},%out;

};

# ---   *   ---   *   ---
# ensures names-values arrays are
# of equal size

sub regpad($names,$values) {

  my @names=@$names;
  my @values=@$values;

# ---   *   ---   *   ---
# case A: more names than values

  if(@names>@values) {

    my $i=@values;
    while($i<@names) {
      push @values,$NULL;
      $i++;

    };

# ---   *   ---   *   ---
# case B: more values than names

  } elsif(@names<@values) {

    my $i=@names;
    my $j=1;

    my $k=$#names;

    while($i<@values) {
      push @names,"$names[$k]+$j";
      $i++;$j++;

    };
  };

  return (\@names,\@values);

};

# ---   *   ---   *   ---
# pushes key:value to array

sub regfmat($dst,$names,$values) {

  while(@$names) {

    my $name=shift @$names;
    my $value=shift @$values;

# NOTE: this is a dereference
#       ill handle it later...
#
#    if(exists $m->{refs}->{$value}) {
#      $value=$m->{refs}->{$value};
#
#    };

    push @$dst,[$name,$value];

  };

};

# ---   *   ---   *   ---
1; # ret
