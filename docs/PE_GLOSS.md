# GLOSS

## SYNOPSIS

Brief manual for peso-centric concepts as well as dict of arspeak terminology.

Because one of the main objectives of peso is simplification of software itself, eyes should be put on this document *remaining* clear and to the point.

## ARSPEAK

Collectively, the programming practices that grew out of avtomat's inception form the AR philosophy: these are simple principles that can be, in one form or another, applied to almost any language, low or high-level.

And central to any system of thought are the words: arspeak captures the ideas and compresses them into mnemonics, serving as a unifying pseudo.

Note that usage of these symbols for different semantic purpuses, when appropiate, and if understood by all members of a team, is perfectly acceptable.

### CORE

First and foremost, we conceive of all blocks of code as components: or "objects", if you must think in such backwards, uneducated terms. But a plain `blk` corresponds to a self-contained cell lacking input *and* output, as well as having no inherent hierarchical value.

The word for "IO-less" is `nihil`; a `nihil blk` proper comprehends no `mess`-ages  and therefore is not an object, but a piece of instantiable, compile-time modifiable, executable memory that can alter the local state of whichever scope it's instantiated in.

A `proc` on the other hand, can `in` values and `ret` them back, on top of encapsulating multiple `blks`, thus holding hierarchical value.

One-way `messes` are `stark`; two-way are `signal`. It's also important to note that a `proc` may only be entered from a unique address, and may only be exited from a unique address as well.

This is limitation for structural purpuses; whenever possible, the format for the input and output data should be layed out at the start of a `proc`, so that the closing `ret` has no semantic value other than giving back the described `out` struct.

Consider the following:

```$

# ---   *   ---   *   ---
# settings

entry  crux;
atexit {fdump};

# see: peso rule $08;
wed --iv-deref;

# ---   *   ---   *   ---
# example signal

proc sum;

  # input struct
  in byte x;
  in byte y;

  # output struct
  out byte z;

  # set out
  cpy z,x+y;

  # give
  ret out;

# ---   *   ---   *   ---
# ^compose

proc sum2;

  # type eq proc
  io sum A;
  io sum B;

  # exec
  call *A &> *B;

  # give 
  ret out;

# ---   *   ---   *   ---
# ^invoke

proc crux;
  io sum2 C;
  ret;

# ---   *   ---   *   ---

```

Because the data formats used by `sum` are known, `sum2` can use the `proc` itself as a data type in defining it's own inputs and outputs; `crux` can then, in turn, do the same with `sum2`.

And so, with `crux` given as `entry`, the program's `fdump` would look as such:

```$

$:non::crux C;
  A => {x,y => z};
  B => {x,y => z};

;>


```

Structure is enforced for greater predictability.
