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

sub SYGEN_KEY {return -JS;};
sub RC_KEY {return 'javascript';};

# ---   *   ---   *   ---

my %JS=(

  -NAME =>'JavaScript',
  -EXT  =>'\.js$',
  -HED  =>'#!.*node',

  -MAG  =>'JavaScript script',

  -COM  =>'//',

# ---   *   ---   *   ---

  -VARS =>[

    [0x04,lang::eiths(

      'async,class,const,extends,function,'.
      'let,this,typeof,var,void'

    ,1)],

    [0x04,lang::eiths(

      'true,false,null,undefined'


    ,1)],

  ],

# ---   *   ---   *   ---

  -BILTN =>[

  ],

# ---   *   ---   *   ---


  -KEYS =>[

    [0x0D,lang::eiths(

      'await,export,import,'.
      'each,in,of,with,yield,finally,'.

      'if,else,for,while,do,switch,case,'.
      'default,try,throw,catch,new,delete,'.
      'break,continue,return'

# probably unexistent
# operator goto

    ,1)],

  ],

# ---   *   ---   *   ---


);$JS{-LCOM}=[
  [0x02,lang::eaf($JS{-COM},0,1)],
  [0x02,lang::delim2('/*','*/',1)],

];lang::DICT->{SYGEN_KEY()}=\%JS;

# ---   *   ---   *   ---
1; # ret
