// ---   *   ---   *   ---
// CASK
// take and give!
//
// LIBRE SOFTWARE
// Licensed under GNU GPL3
// be a bro and inherit
//
// CONTRIBUTORS
// lib,

// ---   *   ---   *   ---
// deps

package SWAN::cask;
  use cmam;
  public use SWAN::mem_prim;


// ---   *   ---   *   ---
// info

  VERSION "v0.00.3a";
  AUTHOR  "IBN-3DILA";


// ---   *   ---   *   ---
// a cask is just a container for
// mem instances which allows for
// slots to be reused as they are freed
//
// 'data' is simply the mem instances
// the cask holds
//
// the 'slot' field then keeps an array of
// bitmasks, which corresponds to available
// memory that can be reused

public typedef struct cask {
  mem   data; // memory pool
  mem   slot; // array of bitmasks

  dword ezy;  // attributes for memory pool
  dword cap;  // (see: mem.c)
  qword flg;

  qword user; // counter goes up whenever access
              // to the container is requested;
              // goes down when released
};
public CX cask CASK_NULL={0};


// ---   *   ---   *   ---
// ^cstruc/dstruc
//
// note the MEM_NEST flag on self->data;
// this is to ensure deleting the cask
// triggers recursive freeing!

CX word CASK_ELEM_CNT  = 64;
CX word CASK_SLOT_MASK = (1*CASK_ELEM_CNT) - 1;

public void cask_new(
  cask ptr self,
  dword ezy,
  dword cap,
  qword flg
) {
  self->data=mem_new(
    sizeof(mem),
    CASK_ELEM_CNT,
    MEM_NEST
  );
  self->ezy=ezy;
  self->cap=cap;
  self->flg=flg;
  self->slot=mem_new(sizeof(qword),1,0x00);
  return;
};

public void cask_delete(cask ptr self) {
  mem_delete(addr self->data);
  mem_delete(addr self->slot);
  return;
};


// ---   *   ---   *   ---
// bitscan && negate-and-bitscan are
// used to find occupied/available slots
// within the array of bitmasks

public IX qword bsf(qword x) {
  return __builtin_ctzll(x);
};

public IX qword nbsf(qword x) {
  return __builtin_ctzll(~x);
};


// ---   *   ---   *   ---
// lookup
//
// used to retrieve a specific slot

typedef struct lkp {
  qword ptr mask; // reference to self->slot
  word      bit;  // ^bit used in mask
  dword     eid;  // ^idex into self->mask
};


// ---   *   ---   *   ---
// put new empty mask

void IX cask_new_slot(
  cask ptr self,
  lkp  ptr dst
) {
  // put new mask for CNT elems
  dword top=self->slot.use;
  mem_push_qword(addr self->slot,0x00);
  dst->mask = mem_at(addr self->slot,top);
  dst->bit  = 0;
  dst->eid  = top;

  // ensure there's at least CNT more elems avail
  mem_skip(
    addr self->data,
    CASK_ELEM_CNT*sizeof(mem)
  );

  return;
};


// ---   *   ---   *   ---
// given a cask find the first free slot

void cask_avail(
  cask ptr self,
  lkp  ptr dst
) {
  // no mask pushed yet?
  dword top=self->slot.use;
  if(top == 0)
    return cask_new_slot(self,dst);

  // ^else walk _backwards_ (newest first)
  qword ptr mask=mem_at(addr self->slot,--top);
  while(top > 0 && ptr mask == UINT64_MAX)
    mask=mem_at(addr self->slot,--top);

  // ^no viable mask found, push new
  if(top == UINT64_MAX || ptr mask == UINT64_MAX)
    return cask_new_slot(self,dst);


  // viable mask, get first avail bit
  if(ptr mask != 0)
    dst->bit=nbsf(ptr mask);

  // or if mask is empty, the bit is zero ;>
  else
    dst->bit=0;

  // set mask and give
  dst->mask = mask;
  dst->eid  = top;
  return;
};


// ---   *   ---   *   ---
// request buffer from static container
//
// will either give existing or
// allocate more memory ;>

public relix cask_take(
  cask ptr self
) {
  // get free or new slot, mark it as occupied
  lkp avail={0};;
  cask_avail(self,addr avail);
  ptr avail.mask |= 1LLU << avail.bit;

  // buffer idex (into self->data)
  // (mask number * elements per mask) + slot number
  dword idex=(avail.eid*CASK_ELEM_CNT)+avail.bit;

  // ^guard that it can fit
  if(idex > RELIX_MAX)
    throw("full cask");

  // ^init mem instance at idex
  mem ptr have=mem_at(addr self->data,idex);
      ptr have=mem_new(self->ezy,self->cap,self->flg);

  // ^give idex
  relix bufid=idex;
  return bufid;
};


// ---   *   ---   *   ---
// ^retrieves element from uid

public IX mem ptr cask_at(
  cask  ptr self,
  relix     bufid
) {
  return mem_at(addr self->data,bufid);
};


// ---   *   ---   *   ---
// ^release ownership of element
//
// cask will mark it as avail for reuse!

public void cask_give(
  cask  ptr self,
  relix     bufid
) {
  // lower 6 bits of bufid are slot idex
  // upper 10 bits are mask idex
  word bit = bufid & CASK_SLOT_MASK;
  word eid = bufid / CASK_ELEM_CNT;

  // free slot for reuse
  qword ptr mask  =  mem_at(addr self->slot,eid);
        ptr mask &=~ (1LLU << bit);

  // free the mem itself
  // if it's already freed, this does nothing
  mem ptr m=mem_at(addr self->data,bufid);
  mem_delete(m);

  return;
};


// ---   *   ---   *   ---
// validates instance

public IX bool cask_invalid(cask ptr self) {
  return (
     mem_invalid(addr self->data)
  && mem_invalid(addr self->slot)
  );
};


// ---   *   ---   *   ---
// ensures the static container exists
// for as long as there's at least one user

public IX use_cask(
  cask ptr self,
  dword ezy,
  dword cap,
  qword flg
) {
  ++self->user;
  if(! cask_invalid(self))
    return;

  cask_new(self,ezy,cap,flg);
  return;
};

public IX no_cask(cask ptr self) {
  if(--self->user || cask_invalid(self))
    return;

  cask_delete(self);
  return;
};


// ---   *   ---   *   ---
// RET
