#!/usr/bin/python

# ---   *   ---   *   ---
# base types/utils

from ctypes import (

  Structure,

  POINTER   as star,

  c_void_p  as pe_void_ptr,
  c_char_p  as byte_str,
  c_wchar_p as wide_str,

  c_int8    as sbyte,
  c_int16   as swide,
  c_int32   as sbrad,
  c_int64   as sword,

  c_uint8   as byte,
  c_uint16  as wide,
  c_uint32  as brad,
  c_uint64  as word,

  c_float   as real,
  c_double  as daut,

  byref,
  pointer,
  cast,

  cdll,

);

import struct;

# ---   *   ---   *   ---
# some additional types

pe_void=None;

sbyte_ptr=star(sbyte);
byte_ptr=star(byte);
swide_ptr=star(swide);
wide_ptr=star(wide);

sbrad_ptr=star(sbrad);
brad_ptr=star(brad);
sword_ptr=star(sword);
word_ptr=star(word);

real_ptr=star(real);
daut_ptr=star(daut);

wide_str_ptr=star(wide_str);
byte_str_ptr=star(byte_str);

#   ---     ---     ---     ---     ---
# typing helper

PRIMITIVES={

  byte_str:{'sz':1,'fmat':'s'},
  wide_str:{'sz':2,'fmat':'ls'},

  sbyte:{'sz':1,'fmat':'b'},
  swide:{'sz':2,'fmat':'h'},
  sbrad:{'sz':4,'fmat':'i'},
  sword:{'sz':8,'fmat':'q'},

  byte:{'sz':1,'fmat':'B'},
  wide:{'sz':2,'fmat':'H'},
  brad:{'sz':4,'fmat':'I'},
  word:{'sz':8,'fmat':'Q'},

  real:{'sz':4,'fmat':'f'},
  daut:{'sz':8,'fmat':'d'},

# ---   *   ---   *   ---

  pe_void_ptr:{'sz':8,'fmat':'P'},

  byte_str_ptr:{'sz':1,'fmat':'s','deref':byte},
  wide_str_ptr:{'sz':2,'fmat':'ls','deref':wide},

  sbyte_ptr:{'sz':1,'fmat':'b','deref':sbyte},
  swide_ptr:{'sz':2,'fmat':'h','deref':swide},
  sbrad_ptr:{'sz':4,'fmat':'i','deref':sbrad},
  sword_ptr:{'sz':8,'fmat':'q','deref':sword},

  byte_ptr:{'sz':1,'fmat':'B','deref':byte},
  wide_ptr:{'sz':2,'fmat':'H','deref':wide},
  brad_ptr:{'sz':4,'fmat':'I','deref':brad},
  word_ptr:{'sz':8,'fmat':'Q','deref':word},

  real_ptr:{'sz':4,'fmat':'f','deref':real},
  daut_ptr:{'sz':8,'fmat':'d','deref':daut},

};

#   ---     ---     ---     ---     ---
# bonus utils

def ftb(type,arr):
  return struct.pack(

    ('%s'%len(arr))
  + PRIMITIVES[type]['fmat'],

    *arr

  );

def cstr (s):
  return bytes(s,"utf-8");

def mcstr(type,s):
  return type(cstr(s));

def mcstar(type,l):

  b=bytearray();b.extend(ftb(type,l));

  if('deref' in PRIMITIVES[type]):
    type=PRIMITIVES[type]['deref'];

  return (type*len(l)).from_buffer(b);

#   ---     ---     ---     ---     ---
