#!/usr/bin/perl
# ---   *   ---   *   ---
# DEFS
# Boilerpaste for langdef files
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---
#
# I'd rather do this with a
# copy paste, but perl doesn't
# effen like that
#
# ---   *   ---   *   ---
# deps

package peso::defs;

  use v5.36.0;
  use strict;
  use warnings;

  use Exporter 'import';
  our @EXPORT=qw(

    $SBL_ID
    $SBL_TABLE

    sbl_id
    sbl_new

    DEFINE
    ALIAS

  );

  use lib $ENV{'ARPATH'}.'/lib/';
  use peso::sbl;

# ---   *   ---   *   ---

our $SBL_TABLE=undef;
our $SBL_ID=0;
our $USE_PLPS=0;

# ---   *   ---   *   ---

sub DEFINE($key,$src,$coderef) {

  $SBL_TABLE->DEFINE(
    $key,$src,$coderef,$USE_PLPS

  );
};

# ---   *   ---   *   ---

sub ALIAS($key,$src) {


  $SBL_TABLE->ALIAS(
    $key,$src

  );
};

# ---   *   ---   *   ---

sub sbl_id() {return $SBL_ID++;};
sub sbl_new($use_plps) {

  $USE_PLPS=$use_plps;
  $SBL_TABLE=peso::sbl::new_frame();

};

# ---   *   ---   *   ---
1; # ret
