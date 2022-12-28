# DISCLAIMER

This document contains heavy ar-speak; competence is adviced.

# GRAMMAR

Basic segment can be understood as follows:

```$

# flags
wed -nocase;

# dom
clan grammar;

  # patterns for match
  rom egex;
    re any  [^\s]+;
    re term [\;];

    re xpr <any> \s* <term>;

  # read input
  proc take;
    in byte str ibs;

    on ibs~=<xpr>;
      jmp give,*xpr;

    or exit FATAL;
    off

  # process match
  proc give;
    in byte str res;

    on has $TAB,res;
      call $TAB -> "%res%";

    or jmp take;
    off;

ret non;


```

This block tree locks down patterns into read-only memory, then attempts matching the patterns against an incoming `byte str`, lissed to `ibs`.

Failure results in default `FATAL` prompt being thrown. Else, consume the matched bit and pass it onto a second `proc`.

If the matched bit can be found within the internal symbol table, it is then called.

Essentially, the backbone of the construct is associating a `path str` such as `path::to::blk` with an executable address. Central idea is feeding entry points to tokens, then `sys` them as they are walked on.

Multiple blocks can be associated with a single token. For example:


```$

# pass frame
reg state;
  byte npass $00;
  byte ptr mod nullstr;

# read inputñ
proc take;
  in byte str ibs;

  # get modifier for this pass
  on [npass]>0;
    cpy [mod],'@ctx';
    
    
  off

  # compare
  on ibs~=<egex::xpr>;
    jmp give,*egex::xpr + [mod];

  or exit FATAL;
  off;

ret -creg;
  ++npass;

```

In this new case, a single walk of the branches uses no modifiers. Else, our `path str` is modified to point at a different block.

This allows for the execution of the tree to be layered across passes. The `mam` tradition is solving symbols only after at least two passes, excluding context data from the very first one.

Furthermore, it is sometimes proper to develop each layer as a separate `clan`, `beg`-ueathing any necessary `ROM` from lib. In this way, the text-processing logic itself can be modularized for later reuse.

