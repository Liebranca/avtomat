// ---   *   ---   *   ---
// MEM STRING
// specialized definitions
// for dealing with strings
//
// LIBRE SOFTWARE
// Licensed under GNU GPL3
// be a bro and inherit
//
// CONTRIBUTORS
// lib,

// ---   *   ---   *   ---
// deps

package SWAN::mem_string;
  use cmam;
  public use SWAN::mem;
  #include <string.h>;


// ---   *   ---   *   ---
// get Nth string in buf

public byte ptr mem_at_string(
  mem ptr self,
  dword   i
) {
  dword pos=0;
  for(dword j=0;j < i;++j)
    pos+=strlen(mem_at_byte(self,pos))+1;

  return self->buf+pos;
};


// ---   *   ---   *   ---
// put string at top

public void mem_place_string(
  mem  ptr self,
  byte ptr elem
) {
  strcpy(mem_top(self),elem);
  self->use+=strlen(elem)+1;
  return;
};


// ---   *   ---   *   ---
// ^with automatic resize

public void mem_push_string(
  mem  ptr self,
  byte ptr elem
) {
  mem_brk(self,strlen(elem)+1);
  mem_place_string(self,elem);
  return;
};


// ---   *   ---   *   ---
// RET
