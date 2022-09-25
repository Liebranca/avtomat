#!/usr/bin/python

# ---   *   ---   *   ---
# base types/utils

from ctypes import (

  Structure,

  POINTER   as star,

  c_void_p  as __pe_void_ptr,
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

# ---   *   ---   *   ---
# some additional types

__pe_void=None;

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
# bonus utils

def cstr (s):
  return bytes(s,"utf-8");

def mcstr(type,s):
  return type(cstr(s));

def mcstar(type,l):
  return (type*len(l))(l[:]);

#   ---     ---     ---     ---     ---
