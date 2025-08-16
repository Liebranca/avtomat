// ---   *   ---   *   ---
// deps

#include <errno.h>
#include <stdlib.h>
#include "SWAN/style.h";


// ---   *   ---   *   ---
// info

  VERSION   "0.00.3a";
  AUTHOR    "IBN-3DILA";


// ---   *   ---   *   ---
// error handling

public IX void throw(const byte ptr errme) {
  perror(errme);
  exit(-1);
};


// ---   *   ---   *   ---
