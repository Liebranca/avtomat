// ---   *   ---   *   ---
// TREE
// natural hierarchies
//
// LIBRE SOFTWARE
// Licensed under GNU GPL3
// be a bro and inherit
//
// CONTRIBUTORS
// lib,

// ---   *   ---   *   ---
// deps

  #include <stddef.h>
  #include "SWAN/style.h"
  #include "SWAN/mem.h"
  #include "SWAN/mem_string.h"
  #include "SWAN/cask.h"


// ---   *   ---   *   ---
// info

  VERSION "v0.00.4a";
  AUTHOR  "IBN-3DILA";


// ---   *   ---   *   ---
// root or node, same thing

public struct tree {
  rel cont;   // relative to container
  rel value;  // relative to value

  qword flg;  // typedata

  relix par;  // immediate ancestor
  relix chd;  // first child node
  relix prev; // siblings
  relix next;
};
public typedef struct tree tree;


// ---   *   ---   *   ---
// ROM

public CX word TREE_NODE_ROOT = 0x00;
public CX word TREE_NODE_NULL = (1 << 16) - 1;


// ---   *   ---   *   ---
// RAM

static cask Cache=CASK_NULL;
public use_tree(void) {
  use_cask(
    addr Cache,
    sizeof(tree),
    MEM_GROW,
    0x00
  );
};
public no_tree(void) {no_cask(addr Cache);};


// ---   *   ---   *   ---
// get array of nodes (whole tree)

public mem ptr tree_nodes(tree ref self) {
  return cask_at(addr Cache,asrel(self)->bufid);
};


// ---   *   ---   *   ---
// get instance from relative

public tree ptr tree_deref(tree ref self) {
  return void_deref(
    tree_nodes(self),
    asrel(self)->eid
  );
};


// ---   *   ---   *   ---
// cstruc for tree root

public rel tree_new(
  qword flg,
  rel   value
) {
  // make handle
  rel self={
    // relix for buffer where we
    // store all nodes for this tree
    .bufid=cask_take(addr Cache),

    // relix for this particular node
    .eid=TREE_NODE_ROOT,

  };

  // make instance
  tree ice={
    .cont  = self,
    .value = value,
    .flg   = flg,
    .par   = TREE_NODE_NULL,
    .chd   = TREE_NODE_NULL,
    .prev  = TREE_NODE_NULL,
    .next  = TREE_NODE_NULL
  };

  // ^store it in buffer
  mem_push(tree_nodes(addr self),addr ice);

  // give relative pointer
  return self;
};


// ---   *   ---   *   ---
// gets root node

public tree ptr tree_root(tree ref self) {
  return mem_at(tree_nodes(self),TREE_NODE_ROOT);
};


// ---   *   ---   *   ---
// get node is root

public bool tree_is_root(tree ref self) {
  return asrel(self)->eid == TREE_NODE_ROOT;
};


// ---   *   ---   *   ---
// get prev sibling node

public tree ptr tree_prev_node(
  tree ref self
) {
  self=deref(self);
  if(self->prev == TREE_NODE_NULL)
    return NULL;

  return mem_at(tree_nodes(self),self->prev);
};


// ---   *   ---   *   ---
// get next sibling node

public tree ptr tree_next_node(
  tree ref self
) {
  self=deref(self);
  if(self->next == TREE_NODE_NULL)
    return NULL;

  return mem_at(tree_nodes(self),self->next);
};


// ---   *   ---   *   ---
// get first child

public tree ptr tree_first_child(
  tree ref self
) {
  self=deref(self);
  if(self->chd == TREE_NODE_NULL)
    return NULL;

  return mem_at(tree_nodes(self),self->chd);
};


// ---   *   ---   *   ---
// get last child

public tree ptr tree_last_child(
  tree ref self
) {
  self=deref(self);
  if(self->chd == TREE_NODE_NULL)
    return NULL;

  // get first child
  tree ptr anchor=mem_at(
    tree_nodes(self),
    self->chd
  );

  // ^walk siblings until end
  while(anchor->next != TREE_NODE_NULL)
    anchor=mem_at(tree_nodes(self),anchor->next);

  return anchor;
};


// ---   *   ---   *   ---
// cstruc for tree _node_

public rel tree_new_node(
  tree ref par,
  byte ptr value,
  word     flg
) {
  // get container
  mem ptr m=tree_nodes(par);

  // make relpptr
  rel self={
    // container is shared across all instances
    .bufid=asrel(par)->bufid,

    // elem idex is just top of node container ;>
    .eid=m->use
  };

  // make child instance
  tree child={
    .cont  = self,
    .value = value,
    .flg   = flg,
    .par   = asrel(par)->eid,
    .chd   = TREE_NODE_NULL,
    .prev  = TREE_NODE_NULL,
    .next  = TREE_NODE_NULL
  };

  // is first child?
  if(par->chd == TREE_NODE_NULL)
    par->chd=child.cont.eid;

  // ^nope, chain to parent's last child
  else {
    tree ptr last=tree_last_child(par);
    child.prev=asrel(last)->eid;
    last->next=child.cont.eid;
  };

  // save new node to container buf
  mem_push(m,addr child);

  // give relative pointer
  return self;
};


// ---   *   ---   *   ---
// dstruc whole tree!

public void tree_delete(tree ref self) {
  if(! self || is_nullref(self))
    return;

  cask_give(addr Cache,asrel(self)->bufid);
  self->value=NULL_REF;

  return;
};


// ---   *   ---   *   ---
// dbout

#include <stdio.h>

void tree_repr(
  tree ref self,
  word     depth
) {
  // give [value type]:value
  self=deref(self);
  printf("[%04X]:%04X\n",self->flg,self->value);

  // early exit if no children
  if(self->chd == TREE_NODE_NULL)
    return;

  // ^else recurse for each child
  tree ptr child=tree_first_child(self);
  while(child) {
    tree_repr(child,depth+1);
    child=tree_next_node(child);
  };

  return;
};


// ---   *   ---   *   ---
// ^iface

public void tree_prich(tree ref self) {
  tree_repr(self,0);
  return;
};


// ---   *   ---   *   ---
// RET
