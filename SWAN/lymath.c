// ---   *   ---   *   ---
// LYMATH
// return of the jedi
//
// LIBRE SOFTWARE
// Licensed under GNU GPL3
// be a bro and inherit
//
// CONTRIBUTORS
// lib,

// ---   *   ---   *   ---
// deps

package SWAN::lymath;
  use cmam;
  public use SWAN::style;


// ---   *   ---   *   ---
// info

  VERSION 'v0.00.1a';
  AUTHOR  'IBN-3DILA';


// ---   *   ---   *   ---
// bitscan && negate-and-bitscan
//
// there are typically used to find
// occupied/available slots within a bitmask

public IX qword bsf(qword x) {
  return __builtin_ctzll(x);
};

public IX qword nbsf(qword x) {
  return __builtin_ctzll(~x);
};


// ---   *   ---   *   ---
// up round divide

public IX qword urdiv(qword n,qword ezy) {
  qword rem=n%ezy;
  qword out=n/ezy;

  if(rem)
    ++out;

  return out;
};


// ---   *   ---   *   ---
// RET
