#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO/DEFS
# language definitions

# ---   *   ---   *   ---

-NAMES=>'[_a-zA-Z][_a-zA-Z0-9]',
-OPS=>'[^\s_A-Za-z0-9\.:\\\\]',

-ODE=>'[\(\[\{]',
-CDE=>'[\}\]\)]',

-DEL_OPS=>'[\{\[\(\)\]\}\\\\]',
-NDEL_OPS=>'[^\s_A-Za-z0-9\.:\{\[\(\)\]\}\\\\]',

-PESC=>'\$\:(([^;\\]|;[^>\\]|\\;>|[^\\;>]|\\[^\\;>]|\\[^;]|\\[^>])*);>',

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
