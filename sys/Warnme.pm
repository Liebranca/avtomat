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
# lyeb,

# ---   *   ---   *   ---
# deps

package Warnme;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp qw(croak longmess);
  use Readonly;

  use English qw(-no_match_vars);

  use File::Spec;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Arstd::IO;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(warnproc);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# sets defaults

sub defaults($O) {

  $O->{obj}  //= nulltag;
  $O->{give} //= 1;
  $O->{back} //= 0;
  $O->{lvl}  //= $AR_WARNING;
  $O->{args} //= [];


  return;

};

# ---   *   ---   *   ---
# universal proto

sub warnproc($me,%O) {


  # default and deref
  defaults \%O;

  map {
    $ARG=$$ARG if is_scalarref($ARG);
    $ARG=nulltag if ! $ARG;

  } @{$O{args}};


  # spit out the mess
  errout $me,%O;


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
1; # ret
