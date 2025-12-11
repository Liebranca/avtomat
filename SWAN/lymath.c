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
  use PM Style qw(null);
  public use SWAN::style;


// ---   *   ---   *   ---
// info

  VERSION 'v0.00.2a';
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
// constants for bitmask Fs below

public CX qword ZMASK_0   = 0x7F7F7F7F7F7F7F7FLLU;
public CX qword ZMASK_1   = 0x0101010101010101LLU;
public CX qword ZMASK_2   = 0x8080808080808080LLU;
public CX qword ZMASK_BIT = 7;


// ---   *   ---   *   ---
// gives bitmask where all zero bytes
// are set to $01, and all others to $00
//
// works only for strings in
// ascii range ($00-$7F)

public IX qword zmask_ascii(qword x) {
  x^=ZMASK_0;
  x+=ZMASK_1;
  x&=ZMASK_2;
  return x >> ZMASK_BIT;
};


// ---   *   ---   *   ---
// ^workaround for non-ascii strings

public IX qword zmask(qword x) {
  return (
    zmask_ascii(x)
  & zmask_ascii(x & ZMASK_0)
  );
};


// ---   *   ---   *   ---
// ^inverts the result of either:
//
// [<]: $01 for non-zero bytes
//      $00 otherwise

public IX qword zmask_invert(qword mask) {
  return mask ^ ZMASK_1;
};


// ---   *   ---   *   ---
// ^ shorthand for making the mask
//   and *then* inverting it

public IX qword nzmask_ascii(qword x) {
  return zmask_invert(zmask_ascii(x));
};

public IX qword nzmask(qword x) {
  return zmask_invert(zmask(x));
};


// ---   *   ---   *   ---
// aligns byte ptr to bound

macro internal stral_proto($type) {
  // copy definition to clipboard
  C public qword T#_stral(
    T pptr sref,
    qword bound
  ) {
    // get how much to align by
    qword out=0;
    qword rem=bound - (
      ((qword) ptr sref)
    & (bound-1)
    );

    // ^move ptr by that many bytes
    if(rem != bound) {
      T ptr tmp=ptr sref;
      while(ptr tmp++
      &&    (out+=sizeof(T))
      &&    (rem-=sizeof(T))) continue;

      ptr sref += out;
    };

    return out;
  };

  // give definition with replacements
  return cmamclip(T=>$type);
};


// ---   *   ---   *   ---
// gets length of string

macro internal strlen_proto($type,$fn) {
  // copy definition to clipboard
  C public qword T#_#PREFIX#strlen(qword ptr s) {
    // force qword aligned
    qword out=T#_stral(addr s,8);

    // walk string
    while(ptr ((T ptr) s)) {
      // read next 8 bytes
      qword have=FN(ptr s++);

      // ^empty mask means skip
      if(! have) {
        out+=8;
        continue;
      };
      // ^else add remainder
      qword i=bsf(have);
      out+=(i > 1) ? i >> 3 : 1 ;
      break;
    };

    return out;
  };

  // give definition with replacements
  return cmamclip(
    T      => $type,
    FN     => $fn,
    PREFIX => ('zmask' eq $fn) ? 'pe' : 'c',
  );
};


// ---   *   ---   *   ---
// ^spawn all variations

macro top make_strlen($nd) {
  my $s=null;
  for my $type(qw(byte word)) {
    $s .= stral_proto($type);
    for my $fn(qw(zmask zmask_ascii)) {
      $s .= strlen_proto($type,$fn);
    };
  };

  clnd($nd);
  return strnd($s);
};

make_strlen;


// ---   *   ---   *   ---
// RET
