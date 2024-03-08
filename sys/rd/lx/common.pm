#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX COMMON
# Buncha defs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::lx::common;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    $QLIST
    $OPT_QLIST

    $VLIST
    $OPT_VLIST

    $SYM

    $BARE
    $CURLY
    $PARENS

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

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
# ROM

  Readonly our $QLIST=>cmdarg(['LIST','ANY']);
  Readonly our $VLIST=>cmdarg(

    ['LIST','OPERA','SYM','BARE'],
    value=>'[^\{]'

  );

  Readonly our $OPT_QLIST=>{%$QLIST,opt=>1};
  Readonly our $OPT_VLIST=>{%$VLIST,opt=>1};

  Readonly our $SYM   => cmdarg(['SYM']);
  Readonly our $BARE  => cmdarg(['BARE']);
  Readonly our $CURLY => cmdarg(
    ['OPERA'],value=>'\{'

  );

  Readonly our $PARENS => cmdarg(
    ['OPERA'],value=>'\('

  );

# ---   *   ---   *   ---
1; # ret
