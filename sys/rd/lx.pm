#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX
# Slow runner ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::lx;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Re;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# names of execution rounds

sub passes($class) { return qw(
  parse

)};

# ---   *   ---   *   ---
# makes command args

sub cmdarg($type,%O) {

  # defaults
  $O{opt}   //= 0;
  $O{value} //= '.+';

  # give descriptor
  return {%O,type=>$type};

};

# ---   *   ---   *   ---
# default set of commands

sub cmdset($class) { return {

  echo => [
    cmdarg(['IDEX','ANY'])

  ],

  stop => [],

  cmd  => [

    cmdarg(['BARE']),
    cmdarg(['IDEX','ANY'],opt=>1),
    cmdarg(['OPERA'],value=>'\{'),

  ],

}};

# ---   *   ---   *   ---
# get name of current pass

sub passname($class,$rd) {
  return ($class->passes())[$rd->{pass}];

};

# ---   *   ---   *   ---
# selfex

sub stop_parse($rd,$branch) {
  $rd->perr('STOP');

};

# ---   *   ---   *   ---
# makes new command!

sub cmd_parse($rd,$branch) {

  $branch->prich();

};

# ---   *   ---   *   ---
# type-checks command arguments

sub argchk($class,$rd) {

  # get command meta
  my $CMD  = $rd->{lx}->load_CMD();
  my $key  = $rd->{branch}->{cmdkey};
  my $args = $CMD->{$key}->{-args};
  my $pos  = 0;


  # walk child nodes and type-check them
  for my $arg(@$args) {

    my $have=$class->argtypechk($rd,$arg,$pos);

    throw_badargs($rd,$key,$arg,$pos)
    if ! $have &&! $arg->{opt};

    $pos++;

  };

};

# ---   *   ---   *   ---
# ^guts, looks at single
# type option for arg

sub argtypechk($class,$rd,$arg,$pos) {

  # get anchor
  my $nd  = $rd->{branch};
  my $par = $nd->{parent};

  # walk possible types
  for my $type(@{$arg->{type}}) {

    # get pattern for type
    my $re=$rd->{l1}->tagre(
      $rd,$type => $arg->{value}

    );

    # return node on pattern match
    my $idex = $pos-1;
    my $chd  = $nd->{leaves}->[$pos];

    return $chd if $chd->{value}=~ $re;

  };


  return undef;

};

# ---   *   ---   *   ---
# ^errme

sub throw_badargs($rd,$key,$arg,$pos) {

  my $value = $rd->{branch}->{leaves};
     $value = $value->[$pos]->{value};

  my @types = @{$arg->{type}};


  $rd->perr(

    "invalid argtype for command '%s'\n"
  . "position [num]:%u: '%s'\n"

  . "need '%s' of type "
  . (join ",","'%s'" x int @types),

    args=>[$key,$pos,$value,$arg->{value},@types],

  );

};

# ---   *   ---   *   ---
# generate/fetch command table

sub load_CMD($class) {

  state $cmdset = $class->cmdset();
  state @keys   = keys %$cmdset;

  state $CMD    = {

    ( map {

      # get name of command
      my $key  = $ARG;
      my $args = $cmdset->{$key};

      # get subroutine variants of
      # command per execution layer
      $key => {

        -args=>$args,

        map { $ARG => codefind(
          $class,"${key}_$ARG"

        )} $class->passes()

      };


    } @keys ),


    -re=>re_eiths(

      \@keys,

      bwrap=>1,
      whole=>1

    ),

  };


  return $CMD;

};

# ---   *   ---   *   ---
1; # ret
