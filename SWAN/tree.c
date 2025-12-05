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

package SWAN::tree;
  use cmam;
  use PM Arstd::String qw(gsplit);
  public use SWAN::cask;

  #include <stddef.h>;


// ---   *   ---   *   ---
// info

  VERSION "v0.00.6a";
  AUTHOR  "IBN-3DILA";


// ---   *   ---   *   ---
// root or node, same thing

public typedef struct tree {
  rel cont;   // relative to container
  rel value;  // relative to value

  qword flg;  // typedata

  relix par;  // immediate ancestor
  relix chd;  // first child node
  relix prev; // siblings
  relix next;
};


// ---   *   ---   *   ---
// ROM

public CX word TREE_NODE_ROOT = 0x00;
public CX word TREE_NODE_NULL = (1 << 16) - 1;


// ---   *   ---   *   ---
// RAM

static cask Cache=CASK_NULL;
public void use_tree(void) {
  use_cask(
    addr Cache,
    sizeof(tree),
    MEM_GROW,
    0x00
  );
  return;
};
public void no_tree(void) {
  no_cask(addr Cache);
  return;
};


// ---   *   ---   *   ---
// get array of nodes (whole tree)

public mem ptr tree_nodes(tree ref self) {
  return cask_at(addr Cache,asrel(self)->bufid);
};


// ---   *   ---   *   ---
// get instance from relative

tree ptr tree_deref_impl(
  tree ref self,
  mem  ptr nodes
) {
  return void_deref(nodes,self);
};

public tree ptr tree_deref(tree ref self) {
  return tree_deref_impl(self,tree_nodes(self));
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

public IX tree ptr tree_root(tree ref self) {
  return mem_at(tree_nodes(self),TREE_NODE_ROOT);
};


// ---   *   ---   *   ---
// get node is root

public IX bool tree_is_root(tree ref self) {
  return asrel(self)->eid == TREE_NODE_ROOT;
};


// ---   *   ---   *   ---
// prelude to any dereferencing F;
// the code is always the same, so we generate it

macro label tree_fetch_proto($nd) {
  // get macro parameters
  my ($cmd,$self,$nodes)=parse_as_label($nd);

  // make wrapper body
  my $body=(
    "mem ptr $nodes=tree_nodes($self);"
  . "$self=tree_deref_impl($self,$nodes);"
  );

  // give definition plus wrapper
  return SWAN::cmacro::fwraps(
    $nd,
    '_impl',
    $body,
    $nodes=>'mem ptr',
  );
};


// ---   *   ---   *   ---
// get prev sibling node

tree_fetch_proto self,nodes:
public tree ptr tree_prev_node(tree ref self) {
  if(self->prev == TREE_NODE_NULL)
    return NULL;

  return mem_at(nodes,self->prev);
};


// ---   *   ---   *   ---
// get next sibling node

tree_fetch_proto self,nodes:
public tree ptr tree_next_node(tree ref self) {
  if(self->next == TREE_NODE_NULL)
    return NULL;

  return mem_at(nodes,self->next);
};


// ---   *   ---   *   ---
// get first child

tree_fetch_proto self,nodes:
public tree ptr tree_first_child(tree ref self) {
  if(self->chd == TREE_NODE_NULL)
    return NULL;

  return mem_at(nodes,self->chd);
};


// ---   *   ---   *   ---
// get last child

tree_fetch_proto self,nodes:
public tree ptr tree_last_child(tree ref self) {
  if(self->chd == TREE_NODE_NULL)
    return NULL;

  // get first child
  tree ptr anchor=mem_at(nodes,self->chd);

  // ^walk siblings until end
  while(anchor->next != TREE_NODE_NULL)
    anchor=mem_at(nodes,anchor->next);

  return anchor;
};


// ---   *   ---   *   ---
// cstruc for tree _node_

tree_fetch_proto par,nodes:
public rel tree_new_node(
  tree ref par,
  byte ptr value,
  word     flg
) {
  // make relpptr
  rel self={
    // container is shared across all instances
    .bufid=asrel(par)->bufid,

    // elem idex is just top of node container ;>
    .eid=nodes->use
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
  };;

  // is first child?
  if(par->chd == TREE_NODE_NULL)
    par->chd=child.cont.eid;

  // ^nope, chain to parent's last child
  else {
    // we use the _impl here because we have the
    // nodes at hand and already dereferenced
    // the parent
    tree ptr last=tree_last_child_impl(par,nodes);
    child.prev=asrel(last)->eid;
    last->next=child.cont.eid;
  };

  // save new node to container buf
  mem_push(nodes,addr child);

  // give relative pointer
  return self;
};


// ---   *   ---   *   ---
// dstruc whole tree!

public void tree_delete(tree ref self) {
  if(! self || is_nullref(self))
    return;

  cask_give(addr Cache,asrel(self)->bufid);
  set_null(addr self->value);

  return;
};


// ---   *   ---   *   ---
// dbout

tree_fetch_proto self,nodes:
void tree_repr(
  tree ref self,
  word     depth
) {
  // give [value type]:value
  printf("[%04X]:%04X\n",self->flg,self->value);

  // early exit if no children
  if(self->chd == TREE_NODE_NULL)
    return;

  // ^else recurse for each child
  tree ptr child=tree_first_child_impl(self,nodes);
  while(child) {
    tree_repr_impl(child,depth+1,nodes);
    child=tree_next_node_impl(child,nodes);
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
