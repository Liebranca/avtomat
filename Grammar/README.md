# DISCLAIMER

This document contains heavy ar-speak; competence is adviced.

# SYNOPSIS

The following is a collection of theorycrafting notes and little essays. It may represent experimental models for undergoing or future implementations.

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

Furthermore, it is sometimes proper to develop each layer as a separate `clan`, `beq`-ueathing any necessary `ROM` from lib. In this way, the text-processing logic itself can be modularized for later reuse.

# PLPS

The original peso language pattern syntax or `plps` is now deprecated; parse logic is written entirely in pure peso, to then `xpile` away into target.

To recognize it's status as legacy, we use the header tag `%lps` for language definition `*.rom` files.

Reason behind this lie in that even the current, rather crude implementation of grammars scales better than the now-legacy `plps`, and can also be expressed with greater ease using a single language.

The extent of `plps` functionality is captured in `re` declarations and `~=` match operations. Given a `rom` block such as:


```$

re base   [0-9];
re prefix [afx];
re name   [\w][\-0-9\w]+;

re id     <prefix> <base>;
re c      <id> \s <name>;

```

A `proc` can process it's input, as well as modify the current tree either immediately or by proxy on a future pass by pushing another `proc` into the branch's call stack.

Effectively, cells and branches can be added, rewritten, plucked or matched against for analysis. As this is driven by it's very gears, one may think of it as the program patching itself *as* it's being built.

This allows an `%lpsrom` to describe the lex and structure of a deconstructed piece of text. It must guarantee output matches the language it describes, or out `FATAL`.

# PASSES

Let `chain` be a sequence of transform arrays applied to a branch of a program tree.

Each stage in a branch's `chain` is a `cell`.

The implicit, and purely referential list of all cells is a `pass`, or an iteration of the tree.

Each pass is required to provide a certain set of guarantees, and failure to meet these results in termination of the chain. The parse stage only gives the guarantee that a file can be *parsed* as a given language, and it falls on subsequent passes to build context data and make further checks.

Done so the procedures to be applied can be managed as layers; this editing of the tree in steps, so-called lazy approach, allows for a dynamic pipeline. Since the `proc` to be called on the next pass can be rewritten, the tree can make decisions as it's being walked, and thus each step in `chain` after parse can make predictions on top of giving guarantees about the current state of the data.

Any time predictions are made, they should be checked to be true and failure handled then and there. Predictions must apply to a section of data to be read during or after a future point in time, or rather, a `cell` of a `chain` that's still enqueued for execution.

Any `cell` at any level in the hierarchy may rewrite it's own `chain` or that of others, as well as add, modify or pluck branches from the tree.

Note that predictions of removed branches must still be checked if their target hasn't yet been fred.
