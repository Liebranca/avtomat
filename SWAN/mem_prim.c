// ---   *   ---   *   ---
// MEM PRIM
// specialized definitions
// for dealing with primitives
//
// LIBRE SOFTWARE
// Licensed under GNU GPL3
// be a bro and inherit
//
// CONTRIBUTORS
// lib,

// ---   *   ---   *   ---
// deps

package SWAN::mem_prim;
  use cmam;
  public use SWAN::mem;


// ---   *   ---   *   ---
// place primitive

public IX void mem_place_byte(
  mem ptr self,
  byte elem
) {
  byte ptr top = mem_top(self);
       ptr top = elem;

  self->use+=sizeof(byte);
  return;
};

public IX void mem_place_word(
  mem ptr self,
  word elem
) {
  word ptr top = mem_top(self);
       ptr top = elem;

  self->use+=sizeof(word);
  return;
};

public IX void mem_place_dword(
  mem ptr self,
  dword elem
) {
  dword ptr top = mem_top(self);
        ptr top = elem;

  self->use+=sizeof(dword);
  return;
};

public IX void mem_place_qword(
  mem ptr self,
  qword elem
) {
  qword ptr top = mem_top(self);
        ptr top = elem;

  self->use+=sizeof(qword);
  return;
};


// ---   *   ---   *   ---
// place vector-primitive

public IX void mem_place_xword(
  mem   ptr self,
  xword ptr elem
) {
  xword ptr top = mem_top(self);
        ptr top = ptr elem;

  self->use+=sizeof(xword);
  return;
};

public IX void mem_place_yword(
  mem   ptr self,
  yword ptr elem
) {
  yword ptr top = mem_top(self);
        ptr top = ptr elem;

  self->use+=sizeof(yword);
  return;
};

public IX void mem_place_zword(
  mem   ptr self,
  zword ptr elem
) {
  zword ptr top = mem_top(self);
        ptr top = ptr elem;

  self->use+=sizeof(zword);
  return;
};


// ---   *   ---   *   ---
// push primitive

public IX void mem_push_byte(
  mem ptr self,
  byte elem
) {
  mem_brk(self,sizeof(byte));
  mem_place_byte(self,elem);
  return;
};

public IX void mem_push_word(
  mem ptr self,
  word elem
) {
  mem_brk(self,sizeof(word));
  mem_place_word(self,elem);
  return;
};

public IX void mem_push_dword(
  mem  ptr self,
  dword elem
) {
  mem_brk(self,sizeof(dword));
  mem_place_dword(self,elem);
  return;
};

public IX void mem_push_qword(
  mem ptr self,
  qword elem
) {
  mem_brk(self,sizeof(qword));
  mem_place_qword(self,elem);
  return;
};


// ---   *   ---   *   ---
// push vector-primitive

public IX void mem_push_xword(
  mem   ptr self,
  xword ptr elem
) {
  mem_brk(self,sizeof(xword));
  mem_place_xword(self,elem);
  return;
};

public IX void mem_push_yword(
  mem   ptr self,
  yword ptr elem
) {
  mem_brk(self,sizeof(yword));
  mem_place_yword(self,elem);
  return;
};

public IX void mem_push_zword(
  mem   ptr self,
  zword ptr elem
) {
  mem_brk(self,sizeof(zword));
  mem_place_zword(self,elem);
  return;
};


// ---   *   ---   *   ---
// RET
