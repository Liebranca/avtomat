#!/usr/bin/perl
# ---   *   ---   *   ---
# AVT XCAV
# Divorces symscan from
# mainline Avt
#
# ie, this file exists solely
# to avoid a dependency cycle
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Avt::Xcav;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Storable qw(store);

  use lib "$ENV{ARPATH}/lib";
  use AR;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Arstd::throw;

  use Shb7::Path qw(dirp include);
  use Shb7::Find qw(ffind wfind);

  use Ftype;
  use Ftype::Text::C;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# looks at a single file for symbols

sub file_sbl($f) {
  my $langname=Ftype::ext_to_ftype($f)->{name};

  throw sprintf(
    q[Can't determine language for file '%s'],
    $f,

  ) unless defined $langname;

  # get modules
  my $xcav="Avt\::Xcav\::$langname";
  my $emit="Emit\::$langname";

  AR::cload $xcav,$emit;


  # get symbols
  my $out=$xcav->symscan($f);

  # ^apply type conversions
  for(keys %{$out->{function}}) {
    my $fn   = $out->{function}->{$ARG};
    my $args = $fn->{args};

    $fn->{rtype}=$emit->typecon($fn->{rtype});

    # ^same for every arg
    for my $i(0..(@$args/2)-1) {
      my $t=$emit->typecon($args->[1+$i*2]);
      $args->[1+$i*2]=$t;
    };
  };

  return $out;
};


# ---   *   ---   *   ---
# in:modname,[files]
# write symbol typedata (return,args) to shadow lib

sub symscan($mod,$dst,$deps,@fname) {
  # early exit if nothing to do
  return if ! @fname;

  # setup search path
  include(dirp($mod));

  # expand file list from names
  my @file=map {
    grep {$ARG} ($ARG=~ qr{\%})
      ? wfind($ARG)
      : ffind($ARG)
      ;
  } @fname;

  my $shwl={
    dep    => $deps,
    fswat  => $mod,
    object => {},
  };


  # iter through expanded list
  for(@file) {
    my $o=Shb7::Path::obj_from_src($ARG);
    relto_root($o);

    $shwl->{object}->{$o}=file_sbl($ARG);

  };

  store($shwl,$dst) or throw $dst;
  return;
};


# ---   *   ---   *   ---
1; # ret
