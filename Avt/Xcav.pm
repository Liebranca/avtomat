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

  use English;
  use Storable qw(store);
  use Carp;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;
  use Arstd::IO qw(errout);
  use Arstd::PM qw(cload);

  use Shb7;

  use Ftype;
  use Ftype::Text::C;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# looks at a single file for symbols

sub file_sbl($f) {
  my $langname=Ftype::ext_to_ftype($f)->{name};

  errout(
    q[Can't determine language for file '%s'],

    args => [$f],
    lvl  => $AR_FATAL,

  ) unless defined $langname;


  # get modules
  my $xcav="Avt\::Xcav\::$langname";
  my $emit="Emit\::$langname";

  cload $xcav,$emit;


  # get symbols
  my $out=$xcav->symscan($f);

  # ^apply type conversions
  for my $key(keys %{$out->{functions}}) {

    my $fn   = $out->{functions}->{$key};
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

sub symscan($mod,$dst,$deps,@fnames) {

  Shb7::push_includes(
    Shb7::dir($mod)

  );

  my @files=();


  # iter filelist
  { for my $fname(@fnames) {

      if( ($fname=~ m/\%/) ) {
        push @files,@{ Shb7::wfind($fname) };

      } else {
        push @files,Shb7::ffind($fname);

      };

    };

  };


  my $shwl={

    deps    => $deps,
    fswat   => $mod,

    objects => {},

  };


  # iter through files
  for my $f(@files) {

    next if !$f;

    my $o=Shb7::obj_from_src($f);
    $o=Shb7::shpath($o);

    $shwl->{objects}->{$o}=file_sbl($f);

  };

  store($shwl,$dst) or croak strerr($dst);
  return;

};


# ---   *   ---   *   ---
1; # ret
