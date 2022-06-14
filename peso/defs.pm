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

# ---   *   ---   *   ---

sub DEFINE($$$) {

  $SBL_TABLE->DEFINE(
    $_[0],$_[1],$_[2],

  );
};

# ---   *   ---   *   ---

sub ALIAS($$) {


  $SBL_TABLE->ALIAS(
    $_[0],$_[1]

  );
};

# ---   *   ---   *   ---

sub sbl_id() {return $SBL_ID++;};
sub sbl_new() {$SBL_TABLE=peso::sbl::new_frame();};

# ---   *   ---   *   ---
1; # ret
