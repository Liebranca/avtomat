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

# ---   *   ---   *   ---

lang::def::nit(

  -NAME=>'peso',

  -EXT=>'\.(pe)$',
  -HED=>'\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$',
  -MAG=>'$ program',

  -OP_PREC=>peso::ops->def,

# ---   *   ---   *   ---

  -VARS =>[

    # primitives
    lang::eiths(

      '('.peso::decls::types_re().
      ')'.'[1-9]*,'

    ,1),

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
        keys %{peso::decls::bafa()}

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
      (join ',',keys %{peso::decls::bafc()})

    ,1),

    # directives
    lang::eiths(
      (join ',',keys %{peso::decls::bafb()})

    ,1),

  ],

);

# ---   *   ---   *   ---
1; # ret
