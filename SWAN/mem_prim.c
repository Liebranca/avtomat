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
  use PM Style qw(null);
  use PM Type qw(typefet);
  public use SWAN::mem;


// ---   *   ---   *   ---
// info

  VERSION "v0.00.3a";
  AUTHOR  "IBN-3DILA";


// ---   *   ---   *   ---
// generates code string for putting
// value at top of mem

macro internal place_proto($type) {
     $type = typefet($type);
  my $tag  = ($type->{sizeof} > 8) ? 'ptr' : null ;
  my $T    = $type->{name};

  return join("\n",
    "public IX void mem_place_${T}(",
      "mem ptr self,",
      "${T} $tag elem",
    ") {",
      "${T} ptr top=mem_top(self);",
      "     ptr top=$tag elem;",

      "self->use+=urdiv(sizeof(${T}),self->ezy);",
      "return;",
    "};\n"
  );
};


// ---   *   ---   *   ---
// ^same, except it pushes ;>

macro internal push_proto($type) {
     $type = typefet($type);
  my $tag  = ($type->{sizeof} > 8) ? 'ptr' : null ;
  my $T    = $type->{name};

  return join("\n",
    "public IX void mem_push_${T}(",
      "mem ptr self,",
      "${T} $tag elem",
    ") {",
      "mem_brk(self,sizeof(${T}));",
      "mem_place_${T}(self,elem);",
      "return;",
    "};\n"
  );
};


// ---   *   ---   *   ---
// generate one version of each proto per type

macro top make($nd) {
  my $s=null;
  for(qw(
    byte  word  dword qword
    xword yword zword
  )) {
    $s .= place_proto($ARG);
    $s .= push_proto($ARG);
  };

  clnd();
  return strnd($s);
};

make;


// ---   *   ---   *   ---
// RET
