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

sub SYGEN_KEY {return -PESO;};
sub RC_KEY {return 'peso';};

# ---   *   ---   *   ---

my %PESO=(

  -NAME=>'peso',

  -EXT=>peso::decls::ext,
  -HED=>peso::decls::hed,
  -MAG=>peso::decls::mag,
  -COM=>peso::decls::com,

  -EXP_BOUND=>';',
  -SCOPE_BOUND=>'\{\}',

# ---   *   ---   *   ---

  -VARS =>[

    # primitives
    [0x04,lang::eiths(

      '('.peso::decls::types_re().
      ')'.'[1-9]*,'

    ,1)],

    # intrinsics
    [0x04,peso::decls::intrinsic],

    # simbolic constants (sblconst)
    [0x04,lang::eiths(

      'self,null,non,other'

    ,1)],

  ],

# ---   *   ---   *   ---

  -BILTN =>[

    # instructions
    [0x01,lang::eiths(

      ( join ',',
        keys %{peso::decls::bafa()}

      ).','.

      'mem,fre,'.
      'shift,unshift,'.

      'kin,sow,reap,'.
      'sys,stop'

    ,1)],

  ],

# ---   *   ---   *   ---

  -KEYS =>[

    # program flow
    [0x0D,lang::eiths(
      (join ',',keys %{peso::decls::bafc()})

    ,1)],

    # directives
    [0x0D,lang::eiths(
      (join ',',keys %{peso::decls::bafb()})

    ,1)],

  ],

# ---   *   ---   *   ---

);$PESO{-LCOM}=[
  [0x02,lang::eaf($PESO{-COM},0,1)],

];lang::DICT->{SYGEN_KEY()}=\%PESO;

# ---   *   ---   *   ---
1; # ret
