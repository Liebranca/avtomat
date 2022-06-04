#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO
# $ syntax defs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package langdefs::peso;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;

  use peso::decls;
  use peso::ops;

# ---   *   ---   *   ---

lang::def::nit(

  -NAME=>'peso',

  -EXT=>'\.(pe)$',
  -HED=>'\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$',
  -MAG=>'$ program',

  -OP_PREC=>peso::ops->def,
  #-SBL=>,

# ---   *   ---   *   ---

  -TYPES=>[
    keys %{peso::decls->TYPES},

  ],

  -SPECIFIERS=>[
    keys %{peso::decls->SPECIFIERS},

  ],

  -RESNAMES=>[qw(
    self other null non

  )],

# ---   *   ---   *   ---

  -INTRINSICS=>[
    keys %{peso::decls->INTRINSICS},

  ],

  -DIRECTIVES=>[
    keys %{peso::decls->DIRECTIVES},

  ],

# ---   *   ---   *   ---

  -BUILTINS=>[qw(

    mem fre shift unshift
    kin sow reap sys stop

  ),keys %{peso::decls->BUILTINS},

  ],

);

# ---   *   ---   *   ---
1; # ret
