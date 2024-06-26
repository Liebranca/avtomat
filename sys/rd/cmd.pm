#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:CMD
# Node subroutines
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmd;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use parent 'rd::cmd::MAKE';
  use parent 'rd::cmd::argproc';
  use parent 'rd::cmd::treeproc';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.6;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
1; # ret
