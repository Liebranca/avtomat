## DISCLAIMER

This still-developing document is written in a still-developing language, and thus may contain some still-developing ideas. ;>

## SYNOPSIS

What follows is a series of snippets written in peso, utilized to illustrate the core rules of the language.

Examples still under construction.

## THE $10 RULES

### `<$00>` Memory layout should be obvious

```$

unwed --iv-deref;

# peso is addicted to strict alignments;
#
# each individual decl takes at
# least one (by-deft) 16-byte unit

byte s '$$$$' =>

# s   s+2  s+4 s+6    s+8 s+A  s+C s+E
  24242424 00000000 : 00000000 00000000;

# all types are fixed-size; so you can
# tell how big your structs are and
# pack accordingly

wide a,b,c,d '$$','!!','%%','##' =>

# a   b    c   d      d+1 d+2  d+3 d+4
  24242121 25252323 : 00000000 00000000;

```

### `<$01>` Readable is better

```$
```

### `<$02>` No significant whitespace

```$

# I am Liebranca, not Walrus van Rossum
sow {/:f}
  'value A','value B',
  'value C','value D',

;

# ^is the same as writing it all in
# one line without spaces
sow{*x}'value A','value B','value C','value D',;

# ^horrible, but neither crashes
#
# spaces are just for clarity, you know,
# since we're not using punchcards anymore...
#
# note how you don't need to parenthesize nor escape;
# the wonders of NOT using $0A as a terminator
#
# we do use {} curlies and () parens to
# enclose nested calls and operations,
# respectively

cpy x,{fn y} + ((z+w) * x);

# ^which you could rewrite however you want,
# as breaking it into lines is possible
#
# so, you can CHOOSE how you want to format,
# and without any extra hassle

cpy x,

  {fn y}
+ ((z+w) * x)
;

# ^if that's your jam, go for it
# if it's not, do whatever else
#
# the language is not going to enforce
# either style on you

cpy x,{fn y}

+

((z+w) * x);

# ^also doesn't crash. I could go on.
#
# fctl is done with keywords,
# not indententation

# A is true
on condition_A;
  ...;

# B is true
or condition_B;
  ...;

# ^none of them are
or;
  ...;

# end of switch
off;


# nesting works like you think it would
on 1;

  on condition_C;
    ...;

  off;

off;

# best of all:
#
# a single, harmless code formatting anomaly,
# be it mistake, laziness or deviance,
# will NOT crash your entire program

cpy x,y;
 cpy z,w;

# ^that one space will not throw you a
# traceback, as if that was a sane thing to do
#
# whitespace only matters in lexing,
# because that's the only time it makes sense

cpy xx,y;

# ^is not the same as
cpyx x,y;

# note that this section does not
# need such a long explanation
#
# however, I enjoy beating this dead horse

```

### `<$03>` No `fwd decls`

```$

# given
reg vars;

  byte x [y];
  byte y $00;

# ^the value of x will be the address of y
# ie, names aren't solved until all names
# are found
#
# likewise for procs

proc ins;
  io   ins2;
  call *ins2;

proc ins2;
  ...;

```

### `<$04>` No inference; be explicit

```$

# as previously mentioned, types are fixed-size;
# we like to know how wide values are
#
# therefore: no anots and no going-walrus;
# DECL your stuff

real v 0.1; # <- correct
def  v 0.1; # <- a crime against humanity

# the io keyword exists solely to save typing;
# it requires that decls are made somewhere

io ins X; # copies in/out decls from proc ins

# if a block utilizes a format with multiple
# procedures attached, yet only requires calling
# a few of them, then it's worth being specific

# here, name has access to the full definition
io [reg] [name];

# ^whereas here name has access to a single proc
io [reg]->[proc] [name];

```

### `<$05>` Recursion is distasteful, not forbidden

```$

# there are things that can't be writen without it
reg Tree;
  void ptr value;
  Tree ptr child;

# worse still
proc walk;

  # init array of nodes
  blk decls;
    Tree buf branch;
    ...;

    push branch,self;

  # ^iter thru
  blk loop;
    on leaf from branch;
      ...;

      ushf branch,leaf->child;
      rept;

    off;

  ret;

# eh, just forget about it
proc dup;

  # inherit
  beq walk;

  # pasted at "..."
  blk decls;
    out Tree new;
    cpy new,self;

  # ^recurse
  blk loop;
    push new->child,*leaf->dup;

  ret;
  

```

### `<$06>` Praise `goto` and use it wisely

```$

# oh, how woe befell a famous dutchman
# in the form of "one small title change
# and suddenly I'm the poster child for
# one of the most dogmatic, insane stances
# among computer scientists"
#
# except not really.
#
# first off, Dijks makes Stack look like
# a welcoming place. rightfully, these
# are the lunatics that enshrine him.
#
# second: have YOU read the paper?
# https://www.cs.utexas.edu/~EWD/transcriptions/EWD02xx/EWD215.html
#
# for a twister, lets paraphrase the
# very first paragraph, emphasis mine:
#
# "[oh boy] DID I become CONVINCED it [goto]
# should be ABOLISHED from EVERYTHING
# except (PERHAPS!) ALL but PLAIN MACHINE CODE"
#
# remarkably spicy choice of words.
# did Wirth change this bit too or what?
#
# Dijks was plagued by this for the rest
# of his life; and decades after his death
# we are still plagued by his bad-mouthing.
#
# anyhoo, this is fine:

proc fn;

  in  byte ptr x;
  out byte y;

  # throw
  jif skip,{null x};
  ...;

  # ^catch
  blk skip;
    ...;

  ret;

# a conditional jump-ahead within a
# single block is harmless; but you
# might ask:
#
# > why not just add keywords for it?
#
# and so, the situation is as follows:
#
# A) bloating the spec with clauses
#    that abstract away the more
#    primitive approach only to then
#    be largely rejected for their
#    inherent dullness, ala try-catch
#    or break in the middle of a single-run
#    do-while, God have mercy on your soul
#
# B) having jumps
#
# by itself, goto is no more problematic
# than inlining and inheritance
#
# what do I mean by this?
#
# consider the english tongue: one can
# *certainly* (ab)use it for evil, through
# witty, malicious remarks amidst Holy Flamewars
# that greatly diminish an opposing individual's
# sense of self-worth.
#
# well then, are we abolishing language?
# how about abolishing the internet? ;>
#
# this is an easy game to play
# and you can play it too!
#
# let us ban kitchen knives worldwide as
# they've been known to be good for cutting;
# they can *literally* be considered harmful
#
# or better yet, ban metallurgy. no more knives,
# axes, spears, shields, swords nor guns.
#
# say, rocks are so primitive. too much of
# an invitation  to grind on a whetstone
# and get to waging war on neighboring
# tribes of neanderthals
#
# well, DID I become convinced that BUCKETS
# FULL OF WATER should be abolished since they
# can be used for drowning living things in
#
# once again, I could go on.
#
# but maybe "can be misused" calls for discipline
# rather than elimination, and the contrary
# is at best fifth a thought.
#
# Dijks was either a cleverly disguised fool
# or the ultimate shitposter, perhaps both.
#
# back to the only real problem:

blk loop;
  on x from ar;
    ...;

    shf ar;
    jmp loop;

  off;

# ^is common enough that
on x from ar;
  ...;
  rept;

off;
 
# becomes acceptable, but we *are* falling
# into the too-many-keywords trap. that's the
# tradeoff we'll sometimes have to make
#
# however, if the only way to loop is using
# an instruction to "rewind" the program, doesn't
# that mean omitting an instruction would result
# in no looping being done?
#
# yes. one way or another, you must EXPLICITLY
# acknowledge that you are, in fact, using goto.
#
# is this strictly necessary for any
# technical reasons? absolutely not, it's
# just a way to poke fun at computer scientists'
# long tradition of doctrinaire ignorance
#
# there's no need for a more complex clause;
# this is fine

proc fn;

  in byte buf ar;

  # lvl0
  on x from ar;

    # lvl1
    on y from x;

      # nested break
      jif tail,y<$80;

      # continue
      rept;

    off;

  off;

  blk tail;
  ret;

```

### `<$07>` Minimize entry points

```$
```

### `<$08>` Every `bare` is a `ptr`

```$

# its "inverted asm" syntax
(x->value) + (y->value)  => x+y;
(x->addr ) + (y->addr )  => [x+y];

# thus,
(x->addr ) + (y->value)  => [x]+y;

# this behaviour can be overriden:
unwed --iv-deref;

# ^such that
(x->value) + (y->value)  => [x]+[y];
(x->addr ) + (y->addr )  => x+y;

# and,
(x->addr ) + (y->value)  => x+[y];

```

### `<$09>` Every `ptr` can be messed with

```$
```

### `<$0A>` `type eq proc`

Main article: [https://github.com/Liebranca/avtomat/blob/main/docs/on-typing.md](types in the peso headspace)

```$
```

### `<$0B>` `value` is just some number

```$
```

### `<$0C>` `void` is absence of `type`

```$
```

### `<$0D>` `null` is absence of `value`

```$
```

### `<$0E>` `reap` what you `sow`

```$
```

### `<$0F>` Don't write to `non`

```$
```

# SO WHAT IS PESO?

In short: a bytestream interpreter. Originally a mere crude technique for embedding hooks into strings, first implemented in Python to draw ANSI-heavy TUIs of all things.

I refined the thinking behind it over time, found new uses for it, and soon realized that I could make a programming language from the mechanisms I had developed.

And so, again, what is Peso?

One, a series of structs for handling binary blocks. Because of the ANSI escape affaire in it's DNA, the idea of a continuous read->exec->insert loop is right at the core of Peso: it's not necessarily the only thing it can do, but it's a big part of how it works.

To illustrate, consider the following draw function:

```$

byte str lines

  '0: some text',
  '1: some more text',
  '2: ^idem'

;

byte y 0;

print_lines:

  # write '\e[y;1H'
  sow {*stdout} '\e[' [y]+1 ';1H' lines[y];

  # go to next
  inc y;

  on y<2;
    jmp print_lines;

  # flush
  or reap;


```

For each line, we are positioning the cursor and pasting the corresponding text. In order to do this, we need to interpolate (or rather `ipol`) the `y` value into the string; effectively, there is a function call in the middle of our data.

Early Peso was entirely dedicated to tackling this kind of problem: the solution was that updates to the draw buffer contained both the operations and data. It looks something like this:

```$

byte str lines 

  # declare y
  $:byte y 0;>

  # move cursor
  $:mvcur y,1;>

  # increment (returns index)
  $:y++;> ': some text'

  # repeat last two commands
  $:rpt -2;> ': some more text'

  # and keep repeating
  $:rpt;> ': ^idem'

;

# write and flush
sow {*stdout} lines;
reap;

```

Rather than putting the escapes into the string, the escapes are generated when needed: now an application that knows nothing of ANSI sequences may still handle our draw buffer; the program reading it is free to implement the calls as it sees fit. All Peso does at this level is provide structures to ensure that it's output is trivial to parse, what you do then is up to you.

# HOW DOES IT WORK?

Consider the following structure:

```$
reg Header;

  word magic[2];

  word block_count;
  word block_size;

```

If you fill it out, and prepend it on a file at write, then on open you could do:

```$

Header h;
FILE f 'path/to';

open {*f} -rb;
read {*f} h,Header:size;

```

This is a fairly common and straight-forward way to manage files of variable size, and one you likely have encountered in the wild -- you make it so the very first chunk of the file is a fixed size, and store metadata within it.

And how does this apply to an executable bytestream? Take a look:

```$

# magic  N     ID data_sz  data_sz
9E50B579 10005009 00000000 00000001

# arg0   # pad    # pad    # pad
F11E0001 00000000 00000000 00000000

# data
48656C6C 6F2C2077 6F726C64 21000000

# magic  N     ID data_sz  data_sz
1BE7E4EC 10009EA9 00000000 00000000

```

^let's upack that.

`magic` breaks down into two 16-bit components: the upper one represents the table to lookup addresses from, the lower one sets the typing mode. They are called `dom` and `sigil`, respectively.

Regardless of how fluent you are in hexspeak, if you just squint hard enough, you will see that `9E50` reads `PESO`, and `B579` reads `BSTR` -- equivalent to `byte str`. So: we are looking up a particular address from the Peso table and invoking it in string mode.

Address, in this case, maps to a procedure. `N` is the number of arguments and `ID` corresponds to the function itself. Because they are stored within the same 32-bit half, we call it the `NID`.

`data_sz` simply gives us the stride to the next instruction, given in what we call a 'unit' -- that is, 16 bytes. Following are the arguments, in this case also taking up just a single unit, and then the data itself.

Take a moment to re-read the example: there's a unit for the instruction, a unit for parameters, and another unit for the data... what are the final 16 bytes for?

If you somehow guessed that we interleave data and instructions, that is exactly what we are doing. Remember how I began this section talking about file headers? Well, there you have it.

Say that your loop goes as follows:

```$

repeat:

  get read_sz;
  read {*f} buffer,read_sz;

  on EOF;
    exit;

  or jmp repeat;

```

Conceptually, these things are nigh identical. You read one fixed-size block that describes the next read, then handle the variable-sized block. Repeat.

In-between reads you handle the data transform. The address you are invoking could just be a constant and take no arguments, in which case the transform is simply unshifting the returned const to the data that follows the instruction.

Likewise, it could be a variable, and simply return it's value at that exact point in time. True to the ninth and tenth Peso rules, every name is a pointer and every pointer can be messed with (or jumped to, in this case).

If the address was that of an object, and that object contained an entry proc, it'd be that procedure that'd be run, and whatever value returned would be used. Or maybe the object lacks an entry, and so we just paste it's raw string or numerical representation, depending on the typing mode. Or it might return another object, from which we repeat the process... or it might just return `null`, and be discarded.

Handling these multitude of scenarios from a single address is why we have such a thing as a typing mode, set through the `wed` directive. As stated previously, `type` is just default usage: you are free to redefine it if needed.

Now, let's see what our example looks like in a slightly more human-readable format:

```$

lis f,stdout;

wed byte str;
sow {*f} 'Hello, world!';

reap;

```

`lis` is short for *alias*; it's only useful for generating the bytecode, but isn't present in the final program that is executed. Here, we are just shortening names to a file handle.

`wed`, like previously explained, is setting up the typing mode. In this case, we want to make the following calls in string mode; this maintained until we declare another variable, set another mode or exit the current scope.

`sow` writes to a file handle and `reap` flushes. But you already guessed that from the string we are writting, didn't you? ;>

# HIERARCHICALS

Every language has it's favored structures or gimmicks, or their *what if everything was an X?* type affaire. In peso, that would be trees.

For one, hierarchies are inescapable. But more importantly, a language that was born out of the need for parsing and interpreting text needs it more than any other.

The four hierarchicals are `reg`, `rom`, `clan` and `proc`. The first two denote a writeable or read-only section of a program, respectively. `clan` is akin to an instantiable namespace, and `proc` is for executable segments.

Note that, generally speaking, the words "section" and "segment" are not used interchangeably when describing binaries. I, however, will do so since in common english they are very much synonyms, akin to "block" and "chunk".

You might be wondering where are `class` and `struct`; the answer is that's a mere model of writeable memory, thus `reg` fills that role. The way hierarchicals work allow for this. Consider the following tree:


```
clan A
\-->rom A::const
.  \-->proc A::const::ins
.
\-->reg A::vars
.  \-->proc A::vars::ins

```

Executable code is always parented to memory descriptors; if you're more comfortable with the nomenclature, you may call them methods.
