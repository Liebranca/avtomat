#!/usr/bin/perl
# ---   *   ---   *   ---
# STYLE
# Boilerpaste for constants
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package style;

  use Exporter 'import';
  our @EXPORT=qw(

    NULL
    NULLSTR

  );

# ---   *   ---   *   ---
# constants

use constant {

  NULL=>0xFFB10C00DEADBEEF,
  NULLSTR=>q(),

};

# ---   *   ---   *   ---
1; # ret
