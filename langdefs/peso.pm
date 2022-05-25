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

# ---   *   ---   *   ---

  -TYPES=> peso::type::new_frame(peso::decls->TYPES),

  -VARS=>[

    # intrinsics
    peso::decls::intrinsic,

    # simbolic constants (sblconst)
    lang::eiths(

      'self,null,non,other'

    ,1),

  ],

# ---   *   ---   *   ---

  -BILTN =>[

    # instructions
    lang::eiths(

      ( join ',',
        keys %{peso::decls->BAFA}

      ).','.

      'mem,fre,'.
      'shift,unshift,'.

      'kin,sow,reap,'.
      'sys,stop'

    ,1),

  ],

# ---   *   ---   *   ---

  -KEYS =>[

    # program flow
    lang::eiths(
      (join ',',keys %{peso::decls->BAFC})

    ,1),

    # directives
    lang::eiths(
      (join ',',keys %{peso::decls->BAFB})

    ,1),

  ],

);

# ---   *   ---   *   ---
1; # ret
