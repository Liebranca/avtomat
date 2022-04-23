#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO/DEFS
# language definitions
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::defs;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# its just a big ole hash
# needs fwd decl :c

my %DICT=();

# ---   *   ---   *   ---
# getters

sub names {return $DICT{-NAMES};};
sub ops {return $DICT{-OPS};};
sub cde {return $DICT{-CDE};};
sub ode {return $DICT{-ODE};};
sub del_ops {return $DICT{-DEL_OPS};};
sub ndel_ops {return $DICT{-NDEL_OPS};};
sub pesc {return $DICT{-PESC};};
sub sizes {return $DICT{-SIZES};};
sub op_prec {return $DICT{-OP_PREC};};

sub bafa {return $DICT{-BAFA};};
sub bafb {return $DICT{-BAFB};};
sub bafc {return $DICT{-BAFC};};

sub ext {return $DICT{-EXT};};
sub mag {return $DICT{-MAG};};
sub hed {return $DICT{-HED};};
sub com {return $DICT{-COM};};

# ---   *   ---   *   ---
# actual def

%DICT=(

# ---   *   ---   *   ---
# common patterns

-NAMES=>'[_a-zA-Z][_a-zA-Z0-9]',
-OPS=>'[^\s_A-Za-z0-9\.:\\\\]',

-ODE=>'[\(\[\{]',
-CDE=>'[\}\]\)]',

-DEL_OPS=>'[\{\[\(\)\]\}\\\\]',
-NDEL_OPS=>'[^\s_A-Za-z0-9\.:\{\[\(\)\]\}\\\\]',

-PESC=>'\$\:(([^;\\]|;[^>\\]|\\;>|[^\\;>]|\\[^\\;>]|\\[^;]|\\[^>])*);>',

# ---   *   ---   *   ---
# file stuff

-HED=>'\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$',
-EXT=>'\.(pe)$',
-MAG=>'$ program',
-COM=>'#',

# ---   *   ---   *   ---
# leaps and such

-SIZES=>{

  # primitives
  'char'=>1,
  'wide'=>2,
  'word'=>4,
  'long'=>8,

# ---   *   ---   *   ---
# granularity

  # ptr size
  'unit'=>0x0008,

  # pointers align to line
  # mem buffers align to page

  'line'=>0x0010, # two units
  'page'=>0x1000, # 256 lines

# ---   *   ---   *   ---
# function types

  'nihil'=>8,     # void(*nihil)(void)
  'stark'=>8,     # void(*stark)(void*)

  'signal'=>8,    # int(*signal)(int)

},

# ---   *   ---   *   ---
# builtins and functions, group A

-BAFA=>{

  'cpy'=>[2],
  'mov'=>[2],
  'wap'=>[2],

  'pop'=>['1+1'],
  'push'=>['1+1'],

  'inc'=>[1],
  'dec'=>[1],
  'clr'=>[1],

  'exit'=>[1],

},

# ---   *   ---   *   ---

-BAFB=>{

  'reg'=>[1],
  'rom'=>[1],
  'tab'=>[1],

  'clan'=>[1],
  'proc'=>[1],

  'entry'=>[1],
  'atexit'=>[1],

},

# ---   *   ---   *   ---

-BAFC=>{

  'jmp'=>[1],
  'jif'=>[2],
  'eif'=>[2],

  'call'=>[-1],
  'ret'=>[-1],
  'wait'=>[-1],

},

# ---   *   ---   *   ---
# operator procs and precedence

-OP_PREC=>{

  '*^'=>[0,2,sub {return (shift)**(shift);}],
  '*'=>[1,2,sub {return (shift)*(shift);}],
  '/'=>[2,2,sub {return (shift)/(shift);}],

  '++'=>[3,1,sub {return (shift)+1;}],
  '+'=>[4,2,sub {return (shift)+(shift);}],
  '--'=>[5,1,sub {return (shift)-1;}],
  '-'=>[6,2,sub {return (shift)-(shift);}],

# ---   *   ---   *   ---

  '?'=>[7,1,sub {return int((shift)!=0);}],
  '!'=>[8,1,sub {return int(!(shift));}],
  '~'=>[9,1,sub {return ~int(shift);}],

  '<<'=>[10,2,sub {

    return int(int(shift)<< int(shift));

  }],

  '>>'=>[11,2,sub {

    return int(int(shift)>> int(shift));

  }],

# ---   *   ---   *   ---

  '|'=>[12,2,sub {

    return int(int(shift)| int(shift));

  }],

  '^'=>[13,2,sub {

    return int(shift)^int(shift);

  }],

  '&'=>[14,2,sub {

    return int(int(shift)& int(shift));

  }],

# ---   *   ---   *   ---

  '<'=>[15,2,sub {

    return int((shift)<(shift));

  }],

  '<='=>[15,2,sub {

    return int((shift)<=(shift));

  }],

  '>'=>[16,2,sub {

    return int((shift)>(shift));

  }],

  '>='=>[16,2,sub {

    return int((shift)>=(shift));

  }],

# ---   *   ---   *   ---

  '||'=>[17,2,sub {

    return int(
         (int(shift)!=0)
      || (int(shift)!=0)

    );

  }],

  '&&'=>[18,2,sub {

    return int(
         int((shift)!=0)
      && int((shift)!=0)

    );

  }],

  '=='=>[19,2,sub {
    return int((shift)==(shift));

  }],

  '!='=>[20,2,sub {
    return int((shift)!=(shift));

  }],

  '->'=>[21,2,sub {
    return (shift).'@'.(shift);

  }],

},

# ---   *   ---   *   ---
);1 # ret

