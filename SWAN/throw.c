// ---   *   ---   *   ---
// deps

package SWAN::throw;
  use cmam;
  public use SWAN::style;

  #include <errno.h>;
  #include <stdlib.h>;


// ---   *   ---   *   ---
// info

  VERSION   "0.00.3a";
  AUTHOR    "IBN-3DILA";


// ---   *   ---   *   ---
// error handling

public void throw(const byte ptr errme) {
  perror(errme);
  exit(-1);
};


// ---   *   ---   *   ---
// RET
