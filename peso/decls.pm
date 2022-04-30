#!/usr/bin/perl
# ---   *   ---   *   ---
# DECLS
# Where names are mentioned
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::decls;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---
# its just a big ole hash
# needs fwd decl :c

my %DICT=(

  -BAF_ID=>0,

);

# ---   *   ---   *   ---
# getters

sub id {
  return $DICT{-BAF_ID}++;

};

# ---   *   ---   *   ---

sub names {return $DICT{-NAMES};};
sub ops {return $DICT{-OPS};};
sub cde {return $DICT{-CDE};};
sub ode {return $DICT{-ODE};};
sub del_ops {return $DICT{-DEL_OPS};};
sub ndel_ops {return $DICT{-NDEL_OPS};};
sub pesc {return $DICT{-PESC};};
sub sizes {return $DICT{-SIZES};};
sub op_prec {return $DICT{-OP_PREC};};
sub types {return $DICT{-TYPES}};
sub types_re {return $DICT{-TYPES_RE}};

sub bafa {return $DICT{-BAFA};};
sub bafb {return $DICT{-BAFB};};
sub bafc {return $DICT{-BAFC};};
sub bafd {return $DICT{-BAFD};};
sub bafe {return $DICT{-BAFE};};

sub ext {return $DICT{-EXT};};
sub mag {return $DICT{-MAG};};
sub hed {return $DICT{-HED};};
sub com {return $DICT{-COM};};

# ---   *   ---   *   ---

sub intrinsic {
  return lang::eiths(

    join ',',
    keys %{bafd()},1

  );
};

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

  'cpy'=>[id(),'2<ptr,ptr|bare>'],
  'mov'=>[id(),'2<ptr,ptr>'],
  'wap'=>[id(),'2<ptr,ptr>'],

  'pop'=>[id(),'*1<ptr>'],
  'push'=>[id(),'1<ptr|bare>'],

  'inc'=>[id(),'1<ptr>'],
  'dec'=>[id(),'1<ptr>'],
  'clr'=>[id(),'1<ptr>'],

  'exit'=>[id(),'1<ptr|bare>'],

},

# ---   *   ---   *   ---

-BAFB=>{

  'reg'=>[id(),'1<bare>'],
  'rom'=>[id(),'1<bare>'],
  'tab'=>[id(),'1<bare>'],

  'clan'=>[id(),'1<bare>'],
  'proc'=>[id(),'1<bare>'],

  'entry'=>[id(),'1<bare>'],
  'atexit'=>[id(),'1<ptr>'],

},

# ---   *   ---   *   ---

-BAFC=>{

  'jmp'=>[id(),'1<ptr>'],
  'jif'=>[id(),'2<ptr,ptr|bare>'],
  'eif'=>[id(),'2<ptr,ptr|bare>'],

  #:*;> not yet implemented
  'call'=>[id(),'1<ptr>'],
  'ret'=>[id(),'1<ptr>'],
  'wait'=>[id(),'1<ptr>'],

},

# ---   *   ---   *   ---
# missing/needs rethinking:
# str,buf,fptr,lis,lock

-BAFD=>{

  'wed'=>[id(),'1<bare>'],
  'unwed'=>[id(),'0'],

  'ptr'=>[id(),'0'],

},

# ---   *   ---   *   ---

-BAFE=>{

  #:***;> we need to access this one through
  #:***;> an 'all-types' regex

  'value_decl'=>[
    id(),'-1<ptr|bare>:*-1<ptr|bare>'

  ],

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
# definitions end here

);

# ---   *   ---   *   ---
# shorthand for type-matching pattern

{ my @types=keys %{sizes()};
  $DICT{-TYPES}=\@types;

};$DICT{-TYPES_RE}=join '|',@{types()};

# ---   *   ---   *   ---

1; # ret
