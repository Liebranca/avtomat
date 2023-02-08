# THE PESO MACHINE

## SYNOPSIS

(WIP) Formal description of a virtual machine.

## COMPONENTS

A peso machine is composed of a stack, a heap or `mem` pool and sixteen GPRs, with a standard word size of 8 bytes; all subsequent units of measuring are calculated from it according to the following table:

```$

word eq X;

byte eq word / word;
wide eq word / $04;
brad eq word / $02;

unit eq word * $02;
line eq unit * $04;
page eq line * $40;

```

`unit` is the minimum size of a structure element, and the addresses of all structures align to unit, ie are divisible by the size of two words.

`line` corresponds to the minimum size of an entry in the cache; `page` represents memory granularity.

Special attention needs to be called onto decls:

```$

# total size: 5 units
reg struc;

  # sz eq 1*4; 4/16 1 unit
  byte x0,y0,z0,w0;

  # sz eq 2*4; 8/16 1 unit
  wide x1,y1,z1,w1;

  # sz eq 4*4; 16/16 1 full unit
  brad x2,y2,z2,w2;

  # sz eq 8*4; 32/32, 2 full units
  word x3,y3,z3,w3;

ret;

```

Every declaration is considered a structure element; one does not simply ask for a single byte.

If punning is desired, it can be accomplished via `lis`:

```$

# total size: 2 units
reg struc;

  word w0,w1,w2,w3;

  # alias to fourth byte of first word
  byte lis w0_b4 [w0+4];

```

The aliased section of the structure, if addressed by it's alias, will be treated according to it's assigned type. The typed `lis` dispenses with the need to utilize pointers as shorthand for constant offsets into memory and incurs no runtime penalty on the structure.

