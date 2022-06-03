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
  use peso::type;

# ---   *   ---   *   ---
# utilities

my $BAF_ID=0;sub id {
  return $BAF_ID++;

};

# ---   *   ---   *   ---
# DECLARATIONS START

# ---   *   ---   *   ---
# leaps and such

use constant TYPES=>{

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

};

# ---   *   ---   *   ---
# builtins and functions, group A

use constant BUILTINS=>{

  'cpy'=>[id(),'2<ptr,ptr|bare>'],
  'mov'=>[id(),'2<ptr,ptr>'],
  'wap'=>[id(),'2<ptr,ptr>'],

  'pop'=>[id(),'*1<ptr>'],
  'push'=>[id(),'1<ptr|bare>'],

  'inc'=>[id(),'1<ptr>'],
  'dec'=>[id(),'1<ptr>'],
  'clr'=>[id(),'1<ptr>'],

  'exit'=>[id(),'1<ptr|bare>'],

};

# ---   *   ---   *   ---

use constant DIRECTIVES=>{

  'reg'=>[id(),'1<bare>'],
  'rom'=>[id(),'1<bare>'],
  'tab'=>[id(),'1<bare>'],

  'clan'=>[id(),'1<bare>'],
  'proc'=>[id(),'1<bare>'],

  'entry'=>[id(),'1<ptr>'],
  'atexit'=>[id(),'1<ptr>'],

};

# ---   *   ---   *   ---

use constant FCTLS=>{

  'jmp'=>[id(),'1<ptr>'],
  'jif'=>[id(),'2<ptr,ptr|bare>'],
  'eif'=>[id(),'2<ptr,ptr|bare>'],

  #:*;> not yet implemented
  'call'=>[id(),'1<ptr>'],
  'ret'=>[id(),'1<ptr>'],
  'wait'=>[id(),'1<ptr>'],

};

# ---   *   ---   *   ---
# missing/needs rethinking:
# str,buf,fptr,lis,lock

use constant INTRINSICS=>{

  'wed'=>[id(),'1<bare>'],
  'unwed'=>[id(),'0'],

};

use constant SPECIFIERS=>{

  'ptr'=>[id(),'0'],
  'fptr'=>[id(),'0'],
  'str'=>[id(),'0'],
  'buf'=>[id(),'0'],

};

# ---   *   ---   *   ---

use constant BAFE=>{

  #:***;> we need to access this one through
  #:***;> an 'all-types' regex

  'value_decl'=>[
    id(),'-1<ptr|bare>:*-1<ptr|bare>'

  ],

};

# ---   *   ---   *   ---
# DECLARATIONS END

# ---   *   ---   *   ---

1; # ret
