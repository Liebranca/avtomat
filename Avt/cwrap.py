#!/usr/bin/python

# ---   *   ---   *   ---
# base types/utils

from ctypes import (

  Structure,

  POINTER   as star,

  c_void_p  as __pe_void_ptr,
  c_char_p  as byte_str,
  c_wchar_p as wide_str,

  c_int8    as syte,
  c_int16   as side,
  c_int32   as song,
  c_int64   as sord,

  c_uint8   as byte,
  c_uint16  as wide,
  c_uint32  as long,
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

syte_ptr=star(syte);
byte_ptr=star(byte);
side_ptr=star(side);
wide_ptr=star(wide);

song_ptr=star(song);
long_ptr=star(long);
sord_ptr=star(sord);
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
