#!/usr/bin/python

# ---   *   ---   *   ---

from ctypes import (

  Structure,

  POINTER   as star,

  c_void_p  as voidstar,
  c_char_p  as charstar,

  c_size_t  as size_t,

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

#   ---     ---     ---     ---     ---

def cstr (s): return bytes   (s, "utf-8");
def mcstr(s): return charstar(cstr(s)   );

#   ---     ---     ---     ---     ---
