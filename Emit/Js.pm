#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT JS
# Utils for printing
# javascript docs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Emit::Js;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Path;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Emit::Std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---

sub proc_decl($class,%O) {

  $O{rtype} //= 'void';
  $O{name}  //= 'fn';
  $O{args}  //= [];

  $O{body}  //= $NULLSTR;

  

};

# ---   *   ---   *   ---
1; # ret
