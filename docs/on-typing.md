# TYPES IN THE PESO HEADSPACE

## SYNOPSIS

How the concept of 'type' is a twisted reality and a proposed alternative, including a few example uses at the implementation level.

## PROC EQ TYPE

Type is merely an abstraction we utilize to correspond blocks of raw data to specific structures and instructions. Inheritance of a type provides an extension with the already existing definitions.

You could think of a single program as being itself a type; it maps a structure given by it's set of inputs to an output through a series of operations: it is, very much, doing the same kind of association.

Think of an application that takes a string of words as an input, giving back a series of paragraphs. This application, though sometimes unknowingly so by the author, utilizes pre-compiled libraries that provide adequate access to the input string as handled by the operating system, generally ones native to C or C++.

That, for one, is called portability, small aside. Our application utilizes types of it's own to convert the string of words it receives, then `ipret` the input sequence into a meaningful format for the section that generates the paragraphs, finally writing to output. Along this path, we carry out multiple type conversions from a single string type, mostly independent of how your operating system handles them.

So why is the OS involved? It's responsible for providing access to your computer, therefore required for your program to run. Unless we're doing bare metal and defining strings of our own ;>

And if we were doing so: at a certainly low enough level, we'll find that our declarations are simply sized intervals measured in bytes, sometimes capable of introspecting at a certain layer so that jumps through the decl's elements are possible.

If you had no strings, you'd begin by writing several small programs to remedy; you'd be defining a type and building it out of multiple procedures that shape one or more data formats into a proper abstraction.

This to me is nothing but self-evident, though I am speaking at a very high-level, barely above assembler. Imagine how 'application' being an extension of 'type' is not in the curriculum, and you always have to go around explaining it?

## APPLICATION VS USAGE

A program in the broader sense is a practical application of a specific set of data formats and transforms, one'd suppose that must've had a hand in the coinage. Every new application extends the overarching `use` of the underlying formats and instructions by mere existance.

Note that this notion is, though most implicitly, already in place -- so much so as to influence UI designs, to the point where you'd likely be summing programs by picking on files through an `iface` rather than feeding strings to your shell.

We know a file 'belongs' to a program. But multiple programs may do something *useful* with it, if it's interal formats are known.

But some would ask what is the point of natively cathegorizing by usage rather than individual format? If multiple packs of libraries contain code of a specific usage, as declared by programs themselves, these can be organized into a multitude of uses at every level.

Such is the purpose of `clan`. You'd typically refer to this as 'namespace' -- a crude word that has no deeper meaning beyond avoiding symbol collisions.

Inversed, I am referring to type-collections as families of formats and procedures, which is more to basic, perceived reality; the same formats and procedures will inevitably be used in a multitude of ways.

## ORGANIZATION REQUIRED

Uppon compilation of an individual source file, it's tree meta must be writ to a location identifyiable by it's declared clan; usage can then be registered separately by a recursive `lib` query.

```$

# declaring clans
clan strings;
  ...;

clan hexnot;
  ...;

# ^included into usage
lib <x/for/purpose>;
  use strings;
  use hexnot;

# ^included from usage
lib <y/for/purpose>;
  use <x/for/purpose>;

```

Extreme care to naming being crucial, and the reason why study of linguistics is more important to the nature of programming than mathematics could ever dream of being; expressing clearly of a concrete idea in brief is many times a complex undertaking, which we constantly struggle with.

Querying would take the following form:

```$

clan peso::access;
  version ...;
  author  ...;

reg lib;
  byte str name;
  byte str buf uses;

proc query;

  out  uses tab dst;
  push dst,name=>uses;

  on u from uses;
    read {//:%u%} as self;
    push dst,*query;

    rept;

  off;

ret;

```

And, for example, invoked as such:

```$

lib <usage>;
  use peso::access lib;

proc crux;

  io  lib L;
  out byte str buf;

  on name,uses from L->*query;
    push out,uses;
    rept;

  off;

ret;


```

Or best re-writ, the notion of `proc eq type` kicks in when you utilize definitions as such:

```$

lib <usage>;
  use peso::access lib;

proc uses;

  io  lib->query Q;
  out byte str buf;

  on name,uses from *Q;
    push out,uses;
    rept;

  off;

ret;


```

A `lib` compatible block must be passed in for it's query to be run; but our application does not require any knowledge of procedures other than `query`.

Thus, an additional layer of fine-grain can be achieved, as only the formats and procedures required for the application to run ever need to be associated with it's usage.

Maintaining software utilizing this concept is what takes programming beyond the scope of writing programs. If `proc eq type` then, invevitably, `type eq usage`; the sole difference lies in the level of abstraction we're operating with at a given point in time.

The mental discipline of a software engineer then, requires frequently switching between these layers, where at every level different thought processes are called for.

### TANGENT

In my dreams I see an infinitely recurring structure of arrays that implements a tree, which is navigated to carry out the next step in the simulation. Roots and branches of the tree very well can, within the current mechanical context, define their own way of interpreting the provided input.

Interpretation is everything but trivial to information itself; it's the core of why the flawed, traditional view of 'typing' is even a necessity; the format of data and transforms applied to it are inevitably intertwined.

The separation of these into format, proc and usage is entirely conceptual, a form of labeling the layers of abstraction we constantly navigate in and out of. Defining them as true cathegories of 'things' is counter-productive, as it muddles their actual relationship to one another.

Thus, rather than a description of each, I'd offer the following chain of relations:

- Format gives structure
- Proc applies interpretation to a structure
- Type encapsulates both the structure *and* possible interpretations.
- Usage is the purpose given to a set of types

However, as previously mentioned, usage does not necessarily encompass all and every interpretation of a structure; it selectively plucks what it needs from each and every type, creating it's own encapsulation.

They are, for all intents and purposes, overlapping classes; __use__ of a type cannot be thought of as not being itself a form of typing, neither can structures.

Interpretations, for themselves, have structures of their own. And the structures required by a procedure will be dependant on a usage; in other words, these concepts endlessly recurse.

This is why they cannot be thought of as being different in the common sense -- but they represent a mental coordinate for the programmer, who constantly shifts between steps in the cycle.

However, our problem is not walking through the branches, but naming them accordingly so as to make it clear which mode of thought we must put ourselves in.

## SUB-CLASSING

Given that `proc eq type`, a procedure *can* be the 'typing' part of a declaration:

```$

# X+Y
proc sum;

  # input format
  in byte a;
  in byte b;

  # output format
  out byte a+b;

# ^X+2
proc sum2;

  io sum pet;
  pet.in b=>2;

  *A;

ret;

```

Inputs to a called procedure that aren't overwritten are expected as inputs to the caller. If no new output format is specified, it's inherited from the callee.

As such, procedures can be subclassed and specialized if generics are desired. Consider the following:

```$

# template
proc sum;

  def T byte;
  ...;

  blk input;
    in T a;
    in T b;
    ...;

  blk output;
    out T a+b;
    ...;

# ^specialization
proc rsum;

  # inherit
  beq sum;

  # swap primitive
  redef T real;

ret;

```

Note how our template is given a default primitive to utilize for it's inner structures and then re-utilized to generate a new procedure: and if needed, it's blocks can be added to as well.

```$

proc sum3;

  beq sum;
    in T c;

  blk input;
    out+=c;

ret;

```

Our additions are pasted-in after the `...` ellipses. Effectively, `proc eq type` gives a programmer the true means of re-using existing code: to build variants of procedures by addition and substitution, as well as complex procedures by composition.

## CONCLUSION

In one of the very first peso-docs I wrote, I referred to the language as 'non-typed'; this was for different reasons back then, yet in the present it still applies: peso does away with the traditional view of typing and therefore fails to be cathegorized within the frame of that view.

It is not adequate for anyone or anything to be entirely unboxed without first reason and hopefully second a clear and concise explanation.

Due and despite the foreign nature of my thoughts at this plane of existence, I have attempted to lay down both; mistakes shall be made and corrected as they are found.
