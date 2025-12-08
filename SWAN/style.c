// ---   *   ---   *   ---
// STYLE
// take it or leave it
//
// LIBRE SOFTWARE
// Licensed under GNU GPL3
// be a bro and inherit
//
// CONTRIBUTORS
// lib,

// ---   *   ---   *   ---
// deps

package SWAN::style;
  use cmam;
  use PM Type::MAKE;
  public #include <stdint.h>;


// ---   *   ---   *   ---
// info

  VERSION "v0.00.2a";
  AUTHOR  "IBN-3DILA";


// ---   *   ---   *   ---
// straight asm names

public typedef uint8_t   byte;
public typedef uint16_t  word;
public typedef uint32_t  dword;
public typedef uint64_t  qword;

public typedef int8_t    sign_byte;
public typedef int16_t   sign_word;
public typedef int32_t   sign_dword;
public typedef int64_t   sign_qword;

public typedef float     real;
public typedef double    dreal;


// ---   *   ---   *   ---
// vector primitives

public typedef struct xword {
  dword x;
  dword y;
  dword z;
  dword w;
};

public typedef struct sign_xword {
  sign_dword x;
  sign_dword y;
  sign_dword z;
  sign_dword w;
};

public typedef struct yword {
  xword a;
  xword b;
};

public typedef struct sign_yword {
  sign_xword a;
  sign_xword b;
};

public typedef struct zword {
  xword a;
  xword b;
  xword c;
  xword d;
};

public typedef struct sign_zword {
  sign_xword a;
  sign_xword b;
  sign_xword c;
  sign_xword d;
};


// ---   *   ---   *   ---
// for glm type stuff...

public typedef struct vec2 {
  real x;
  real y;
};

public typedef struct vec3 {
  real x;
  real y;
  real z;
};

public typedef struct vec4 {
  real x;
  real y;
  real z;
  real w;
};

public typedef vec4 quat;


// ---   *   ---   *   ---
// ^integer variants

public typedef struct uvec2 {
  dword x;
  dword y;
};

public typedef struct uvec3 {
  dword x;
  dword y;
  dword z;
};

public typedef struct uvec4 {
  dword x;
  dword y;
  dword z;
  dword w;
};

public typedef struct ivec2 {
  sign_dword x;
  sign_dword y;
};

public typedef struct ivec3 {
  sign_dword x;
  sign_dword y;
  sign_dword z;
};

public typedef struct ivec4 {
  sign_dword x;
  sign_dword y;
  sign_dword z;
  sign_dword w;
};


// ---   *   ---   *   ---
// matrices

public typedef struct mat2 {vec2 col[2];};
public typedef struct mat3 {vec3 col[3];};
public typedef struct mat4 {vec4 col[4];};

public typedef struct umat2 {uvec2 col[2];};
public typedef struct umat3 {uvec3 col[3];};
public typedef struct umat4 {uvec4 col[4];};

public typedef struct imat2 {ivec2 col[2];};
public typedef struct imat3 {ivec3 col[3];};
public typedef struct imat4 {ivec4 col[4];};


// ---   *   ---   *   ---
// so (byte ptr  == uint8_t*)
// && (ptr  name == *name)
// && (addr name == &name)

public #define ptr  *;
public #define pptr **;
public #define addr &;


// ---   *   ---   *   ---
// 'ptr' is for an _actual_ pointer
// 'ref' is used for _relative_ pointers
// (see: union rel)

public #define ref *;


// ---   *   ---   *   ---
// relative pointers are just indices
// (see: mem_at())

public typedef word  relix;
public typedef dword drelix;

public #define RELIX_MAX UINT16_MAX;


// ---   *   ---   *   ---
// shorthands

public #define CX  static const;
public #define IX  static inline;
public #define CIX static inline const;


// ---   *   ---   *   ---
// basis for structs that use
// static containers

public typedef union rel {
  struct {
    relix bufid;
    relix eid;
  };
  drelix value;
};

public CX drelix NULL_REF=(1LLU << 32) - 1;
public IX bool is_nullref(rel ptr self) {
  return self->value == NULL_REF;
};

public IX void set_null(rel ptr self) {
  self->value=NULL_REF;
  return;
};


// ---   *   ---   *   ---
// structs derived from rel would define
// their own dereferencing, which would
// handle fetching the buf from a static container
// using the 'buf_ptr' part of rel
//
// these macros simply allow you to have
// 'type ref' behave the same as 'rel ptr',
// while catching a dereference of 'rel ptr'
// at compile-time

public #define rel_deref(relative)\
  static_assert(\
    false,\
    "'" #relative "' has incomplete type\n"\
  );

public #define mem_deref(relative)\
  static_assert(\
    false,\
    "'" #relative "' has incomplete type\n"\
  );


// ---   *   ---   *   ---
// shorthand for reinterpreting
// 'type ref' as 'rel ptr'

public #define asrel(relative)\
  ((rel ptr) (relative));


// ---   *   ---   *   ---
// RET
