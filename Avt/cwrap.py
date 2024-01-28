#!/usr/bin/python

# ---   *   ---   *   ---
# base types/utils

from ctypes import (

  Structure,

  POINTER   as star,

  c_void_p  as pe_void_ptr,
  c_char_p  as byte_str,
  c_wchar_p as word_str,

  c_int8    as sbyte,
  c_int16   as sword,
  c_int32   as sdword,
  c_int64   as sqword,

  c_uint8   as byte,
  c_uint16  as word,
  c_uint32  as dword,
  c_uint64  as qword,

  c_size_t  as size_t,

  c_float   as real,
  c_double  as dreal,

  py_object as starpy,

  byref,
  pointer,
  cast,

  cdll,

);

import struct;

# ---   *   ---   *   ---
# some additional types

pe_void       = None;

sbyte_ptr     = star(sbyte);
byte_ptr      = star(byte);
sword_ptr     = star(sword);
word_ptr      = star(word);

sdword_ptr    = star(sdword);
dword_ptr     = star(dword);
sqword_ptr    = star(sqword);
qword_ptr     = star(qword);

real_ptr      = star(real);
dreal_ptr     = star(dreal);

word_str_ptr  = star(word_str);
byte_str_ptr  = star(byte_str);

#   ---     ---     ---     ---     ---
# typing helper

PRIMITIVES={

  byte_str  :{'sz':1,'fmat':'s'},
  word_str  :{'sz':2,'fmat':'ls'},

  sbyte     :{'sz':1,'fmat':'b'},
  sword     :{'sz':2,'fmat':'h'},
  sdword    :{'sz':4,'fmat':'i'},
  sqword    :{'sz':8,'fmat':'q'},

  byte      :{'sz':1,'fmat':'B'},
  word      :{'sz':2,'fmat':'H'},
  dword     :{'sz':4,'fmat':'I'},
  qword     :{'sz':8,'fmat':'Q'},

  real      :{'sz':4,'fmat':'f'},
  dreal     :{'sz':8,'fmat':'d'},

# ---   *   ---   *   ---

  pe_void_ptr:{'sz':8,'fmat':'P'},

  byte_str_ptr:{'sz':1,'fmat':'s','deref':byte},
  word_str_ptr:{'sz':2,'fmat':'ls','deref':word},

  sbyte_ptr:{'sz':1,'fmat':'b','deref':sbyte},
  sword_ptr:{'sz':2,'fmat':'h','deref':sword},
  sdword_ptr:{'sz':4,'fmat':'i','deref':sdword},
  sqword_ptr:{'sz':8,'fmat':'q','deref':sqword},

  byte_ptr:{'sz':1,'fmat':'B','deref':byte},
  word_ptr:{'sz':2,'fmat':'H','deref':word},
  dword_ptr:{'sz':4,'fmat':'I','deref':dword},
  qword_ptr:{'sz':8,'fmat':'Q','deref':qword},

  real_ptr:{'sz':4,'fmat':'f','deref':real},
  dreal_ptr:{'sz':8,'fmat':'d','deref':dreal},

};

#   ---     ---     ---     ---     ---
# bonus utils

def ftb(type,arr):
  return struct.pack(

    ('%s'%len(arr))
  + PRIMITIVES[type]['fmat'],

    *arr

  );

def cstr(s):
  return bytes(s,"utf-8");

def cstr8(s):
  return bytes(s,"ascii");

def pastr8(s,t=byte):

  buf=bytearray();

  buf.extend(ftb(t,[len(s)]));
  buf.extend(cstr8(s));

  return buf;

def mcstr(t,s):
  return t(cstr(s));

def mcstar(t,l):

  b=bytearray();
  b.extend(ftb(t,l));

  if('deref' in PRIMITIVES[t]):
    t=PRIMITIVES[t]['deref'];

  return (t*len(l)).from_buffer(b);

#   ---     ---     ---     ---     ---
