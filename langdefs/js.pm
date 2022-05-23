#!/usr/bin/perl
# ---   *   ---   *   ---
# sadface

# ---   *   ---   *   ---

# deps
package langdefs::js;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---

lang::def::nit(

  -NAME =>'js',
  -EXT  =>'\.js$',
  -HED  =>'#!.*node',

  -MAG  =>'JavaScript script',

  -COM  =>'//',

# ---   *   ---   *   ---

  -VARS =>[

    lang::eiths(

      'async,class,const,extends,function,'.
      'let,this,typeof,var,void'

    ,1),

    lang::eiths(

      'true,false,null,undefined'


    ,1),

  ],

# ---   *   ---   *   ---

  -BILTN =>[

  ],

# ---   *   ---   *   ---


  -KEYS =>[

    lang::eiths(

      'await,export,import,'.
      'each,in,of,with,yield,finally,'.

      'if,else,for,while,do,switch,case,'.
      'default,try,throw,catch,new,delete,'.
      'break,continue,return'

    ,1),

  ],
);

# ---   *   ---   *   ---
1; # ret
