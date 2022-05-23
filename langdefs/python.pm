#!/usr/bin/perl
# ---   *   ---   *   ---
# python defs

# ---   *   ---   *   ---

# deps
package langdefs::python;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---

lang::def::nit(

  -NAME =>'python',
  -EXT  =>'\.py$',
  -HED  =>'^#!.*python',

  -MAG  =>'Python script',

  -COM  =>'#',

# ---   *   ---   *   ---

  -VARS =>[

    lang::eiths(

      'str,int,float,list,dict,'.
      ''

    ,1),

    lang::eiths(

      'False,None,True'


    ,1),

    '__$:names;>__',

  ],

# ---   *   ---   *   ---

  -BILTN =>[

  ],

# ---   *   ---   *   ---


  -KEYS =>[

    lang::eiths(

      'def,'.

      'and,as,assert,async,await,'.
      'break,class,continue,'.

      'del,elif,else,except,'.
      'finally,for,from,'.

      'global,if,import,in,is,'.
      'lambda,nonlocal,not,or,'.

      'pass,raise,return,'.
      'try,while,with,yield'

    ,1),

  ],
);

# ---   *   ---   *   ---
1; # ret
