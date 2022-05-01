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

sub SYGEN_KEY {return -PYTHON;};
sub RC_KEY {return 'python';};

# ---   *   ---   *   ---

my %PYTHON=(

  -NAME =>'Python',
  -EXT  =>'\.py$',
  -HED  =>'^#!.*python',

  -MAG  =>'Python script',

  -COM  =>'#',

# ---   *   ---   *   ---

  -VARS =>[

    [0x04,lang::eiths(

      'str,int,float,list,dict,'.
      ''

    ,1)],

    [0x04,lang::eiths(

      'False,None,True'


    ,1)],

    [0x04,'__'.lang::_LUN.'*__'],

  ],

# ---   *   ---   *   ---

  -BILTN =>[

  ],

# ---   *   ---   *   ---


  -KEYS =>[

    [0x0D,lang::eiths(

      'def,'.

      'and,as,assert,async,await,'.
      'break,class,continue,'.

      'del,elif,else,except,'.
      'finally,for,from,'.

      'global,if,import,in,is,'.
      'lambda,nonlocal,not,or,'.

      'pass,raise,return,'.
      'try,while,with,yield'

    ,1)],

  ],

# ---   *   ---   *   ---


);$PYTHON{-LCOM}=[
  [0x02,lang::eaf($PYTHON{-COM},0,1)],
  [0x02,lang::delim2('/*','*/',1)],

];lang::DICT->{SYGEN_KEY()}=\%PYTHON;

# ---   *   ---   *   ---
1; # ret
