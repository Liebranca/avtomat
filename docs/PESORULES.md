# FOREWORD

This still-developing document is written in a still-developing language, and thus may contain some still-developing ideas. ;>

I have decided to code the examples in Peso precisely because that's what I'm trying to teach you, nevermind it's nowhere near finished at this point in time. I can only know that the language is actually any good when simple snippets of it can be understood easily by another programmer, therefore this choice serves a deeper purpose to development than just documentation.

Now, let's get on with it.

# SYNOPSIS

`<0x0>` Memory layout should be obvious.

`<0x1>` Readable is better.

`<0x2>` No significant whitespace.

`<0x3>` No `fwd decls`.

`<0x4>` No inference; be explicit.

`<0x5>` Recursion is distasteful, not forbidden.

`<0x6>` Praise `goto` and use it wisely.

`<0x7>` Minimize entry points.

`<0x8>` Every name is a `ptr`.

`<0x9>` Every `ptr` can be messed with.

`<0xA>` `type` is just default usage.

`<0xB>` `value` is just some number.

`<0xC>` `void` is absence of `type`.

`<0xD>` `null` is absence of `value`.

`<0xE>` `reap` what you `sow`.

`<0xF>` Don't write to `non`.

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
