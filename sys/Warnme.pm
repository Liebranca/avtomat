#!/usr/bin/perl
# ---   *   ---   *   ---
# WARNME
# Messages you love to ignore!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Warnme;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Chk qw(is_scalarref);
  use Arstd::PM qw(rcaller);
  use Arstd::throw;

  use parent 'St';


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(warnproc);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

my $PKG=__PACKAGE__;
St::vconst {
  DEFAULT => {
    obj   => '<null>',
    give  => 1,
    bt    => 0,
    throw => 0,
    args  => [],
  },
};


# ---   *   ---   *   ---
# universal proto

sub warnproc($me,%O) {
  # default and deref
  $PKG->defnit(\%O);
  my $nulltag=$PKG->DEFAULT->{obj};

  map {
    $ARG=$$ARG    if   is_scalarref($ARG);
    $ARG=$nulltag if ! defined $ARG;

  } @{$O{args}};

  # cleanup args for log call
  my $out=$O{give};
  delete $O{obj};
  delete $O{give};

  # default origin to caller
  $O{from} //= rcaller(__PACKAGE__);

  # spit out the mess
  Log->err($me,%O);

  return $O{give};
};


# ---   *   ---   *   ---
# "invalid (WAT): '(OBJ)'"

sub invalid($wat,%O) {
  warnproc "invalid %s: '%s'",%O,
  args => [$wat,$O{obj}];
};


# ---   *   ---   *   ---
# "redefinition of (WAT) '(OBJ)'"

sub redef($wat,%O) {
  warnproc "redefinition of %s '%s'",%O,
  args => [$wat,$O{obj}];
};


# ---   *   ---   *   ---
# "X not found in Y"

sub not_found($wat,%O) {
  my $in=($O{cont})
    ? "in $O{cont}"
    : 'in'
    ;

  # say where the search took place?
  if($O{where}) {
    warnproc "$wat <%s> not found $in <%s>",%O,
    args => [$O{obj},$O{where}];

  # ^nope, just tell result ;>
  } else {
    warnproc "$wat <%s> not found $in",%O,
    args => [$O{obj}];
  };
};


# ---   *   ---   *   ---
1; # ret
