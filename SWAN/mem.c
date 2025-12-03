// ---   *   ---   *   ---
// MEM
// you can't handle it
//
// LIBRE SOFTWARE
// Licensed under GNU GPL3
// be a bro and inherit
//
// CONTRIBUTORS
// lib,

// ---   *   ---   *   ---
// deps

package SWAN::mem;
  use cmam;
  public use SWAN::throw;
  public #include <stddef.h>;

  #include <stdlib.h>;


// ---   *   ---   *   ---
// info

  VERSION "v0.00.8a";
  AUTHOR  "IBN-3DILA";


// ---   *   ---   *   ---
// malloc wrapper

public typedef struct mem {
  dword ezy;    // elem size
  dword cap;    // capacity
  qword use;    // bytes occupied
  qword flg;    // typedata bitmask

  byte ptr buf; // malloc'd buffer
};


// ---   *   ---   *   ---
// ROM

public CX mem   MEM_NULL = {0};
public CX dword MEM_GROW = 64;

public CX qword MEM_NEST = 1LLU << 63;
public CX qword MEM_STR  = 1LLU << 62;


// ---   *   ---   *   ---
// cstruc

public mem mem_new(
  dword ezy,
  dword cap,
  qword flg
) {
  // make ice
  mem self={
    .ezy=ezy,
    .cap=cap,
    .use=0x00,
    .flg=flg,
    .buf=malloc(ezy*cap)
  };;

  // catch malloc error
  if(! self.buf)
    throw("`malloc()` fail on `mem_new()`");

  // give new instance
  return self;
};


// ---   *   ---   *   ---
// get capacity/used capacity

public IX qword mem_bytesz(mem ptr self) {
  return self->ezy*self->cap;
};

public IX qword mem_usedsz(mem ptr self) {
  return self->ezy*self->use;
};


// ---   *   ---   *   ---
// attributes of both blocks are identical
// eg (ptr self == ptr other)

public IX bool mem_equal(
  mem ptr self,
  mem ptr other
) {
  if(self == NULL || other == NULL)
    return false;

  return (self == other) || (
     (self->ezy == other->ezy)
  && (self->cap == other->cap)
  && (self->use == other->use)
  && (self->flg == other->flg)
  && (self->buf == other->buf)
  );
};


// ---   *   ---   *   ---
// get instance is invalid/empty

public IX bool mem_invalid(mem ptr self) {
  return (
     (self      == NULL)
  || (self->buf == NULL)
  || mem_equal(self,addr MEM_NULL)
  );
};

public IX bool mem_empty(mem ptr self) {
  return self && (! self->buf ||! self->use);
};


// ---   *   ---   *   ---
// common fetch buf+[position] ops

public IX byte ptr mem_at(
  mem ptr self,
  dword   i
) {
  return self->buf+self->ezy*i;
};

public CIX byte ptr mem_at_byte(
  mem ptr self,
  dword   i
) {
  return self->buf+i;
};

public IX byte ptr mem_top(mem ptr self) {
  return mem_at(self,self->use);
};

public IX byte ptr mem_bytetop(mem ptr self) {
  return mem_at_byte(self,mem_usedsz(self));
};


// ---   *   ---   *   ---
// mem_at wrapper for relative pointers
//
// this can be used with any struct whose
// first field is a rel, so whether you pass
// in a relative pointer or the actual pointer
// itself gives the same result
//
// NOTE: attempting deref(void* r) will always
//       fail as the signatures won't match ;>
//
//       you have to call this directly for
//       it to work...

public IX void ptr void_deref(
  mem  ptr self,
  void ref r
) {
  return mem_at(self,asrel(r)->eid);
};


// ---   *   ---   *   ---
// dstruc

public void mem_delete(mem ptr self) {
  if(mem_invalid(self))
    return;

  // recurse?
  if(self->flg & MEM_NEST) {
    for(dword i=0;i < self->cap;++i) {
      mem_delete(mem_at(self,i));
    };
  };

  // ^release and give
  free(self->buf);
  ptr self=MEM_NULL;

  return;
};


// ---   *   ---   *   ---
// get relative ptr from base

public IX qword mem_relto(
  mem  ptr self,
  byte ptr other
) {
  return (
    ((qword) other)
  - ((qword) self->buf)
  );
};


// ---   *   ---   *   ---
// bounds-checking

public IX dword mem_byte_boundschk(
  mem ptr self,
  qword   i
) {
  return i % mem_bytesz(self);
};

public IX dword mem_elem_boundschk(
  mem ptr self,
  qword   i
) {
  return i % self->cap;
};


// ---   *   ---   *   ---
// align bytecnt to element size

public IX qword mem_align_n(
  mem ptr self,
  qword   n
) {
  qword diff=n % self->ezy;
  if(diff != 0 && diff != self->ezy)
    n += self->ezy - diff;

  return n;
};


// ---   *   ---   *   ---
// realloc wraps
//
// resizes buf to N bytes, ensuring
// that N is a multiple of element size

public mem ptr mem_resz(
  mem ptr self,
  qword   n
) {
  // get mem
  n         = mem_align_n(self,n);
  self->buf = realloc(self->buf,sizeof(mem)+n);

  // ^catch realloc error
  if(self->buf == NULL)
    throw("`realloc()` fail on `mem_resz()`");


  // update and give
  self->cap=n/self->ezy;
  return self;
};


// ---   *   ---   *   ---
// see whether we can hold N more bytes
//
// if we don't have enough space, then realloc
// else do nothing

public IX dword mem_brkhit(
  mem ptr self,
  qword   n
) {
  return (
    ((sign qword) (mem_usedsz(self) + n))
  - mem_bytesz(self)
  );
};

public IX mem ptr mem_brk(
  mem ptr self,
  qword   n
) {
  sign qword need=mem_brkhit(self,n);
  if(need > 0)
    return mem_resz(
      self,
      (self->cap + need)
    + (self->ezy * MEM_GROW)
    );

  return self;
};


// ---   *   ---   *   ---
// put elem-size bytes at top
// does _not_ check for avail space

public IX void mem_place(
  mem  ptr self,
  byte ptr elem
) {
  memcpy(mem_top(self),elem,self->ezy);
  self->use+=self->ezy;
  return;
};


// ---   *   ---   *   ---
// same as place, but it checks whether
// you can actually add an element
//
// this is useful when you don't know
// how much memory to reserve, which is
// more often than you'd think

public IX void mem_push(
  mem  ptr self,
  byte ptr elem
) {
  mem_brk(self,self->ezy);
  mem_place(self,elem);
  return;
};


// ---   *   ---   *   ---
// marks N bytes as occupied, and allocates
// space if necessary, but does not fill it

public IX void mem_skip(
  mem ptr self,
  qword   n
) {
  mem_brk(self,n);
  n=mem_align_n(self,n);
  self->use+=n/self->ezy;
  return;
};


// ---   *   ---   *   ---
// RET
