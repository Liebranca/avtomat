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
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::Xcav;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Storable;
  use Carp;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::IO;

  use Shb7;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;

  use Lang::C;
  use Lang::Perl;
  use Lang::peso;

  use Grammar::C;

  use Emit::C;
  use Emit::Perl;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# looks at a single file for symbols

sub file_sbl($f) {

  my $langname=Lang::file_ext($f);

  errout(

    q[Can't determine language for file '%s'],

    args => [$f],
    lvl  => $AR_FATAL,

  ) unless defined $langname;

  # get modules
  my $gram="Grammar\::$langname";
  my $emit="Emit\::$langname";

  # read file and strip comments
  my $prog=orc($f);
  $gram->strip(\$prog);

  # get symbols
  my $out=$gram->mine($prog);

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

# ---   *   ---   *   ---
# iter filelist

  { for my $fname(@fnames) {

      if( ($fname=~ m/\%/) ) {
        push @files,@{ Shb7::wfind($fname) };

      } else {
        push @files,Shb7::ffind($fname);

      };

    };

  };

# ---   *   ---   *   ---

  my $shwl={

    deps    => $deps,
    fswat   => $mod,

    objects => {},

  };

# ---   *   ---   *   ---
# iter through files

  for my $f(@files) {

    next if !$f;

    my $o=Shb7::obj_from_src($f);
    $o=Shb7::shpath($o);

    $shwl->{objects}->{$o}=file_sbl($f);

  };

  store($shwl,$dst) or croak strerr($dst);

};

# ---   *   ---   *   ---
1; # ret
