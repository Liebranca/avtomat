# ALIASES AT DIFFERENT LAYERS

## SYNOPSIS

Uppon being introduced to peso, the `def`, `redef` and `undef` directives brought onto me the thought that the `lis` or 'aliasing' keyword was due for deprecation.

For the following reasons, this has not happened.

## NTERM V VALUE

The mainline objective of peso is simplicity, both to the programmer *and* parser, and at the core of this purpose is the following pattern:

### FIGURE $00

```$

rom std;
  wed -nscap;
  re term  [ \;]+;
  re nterm [^\;]+;

reg exprs;
  self std;
  byte str buf;

proc token;
  in byte ptr ibs;

  wed --re-consume;
  on ibs~=^<nterm><term>;
    push self,{*nterm};

  off;

ret;  

```

### REASONING

First we define two patterns: an expression terminator or `term`, and all that is not a terminator, or `nterm`.

The `-nscap` flag corresponds to a lexing dilemma: all unescaped, or allowing escaped characters.

If I ask for all bytes in a string *but* `;` semi-colon, the string "hello \;" will return "hello \", thus we must be more explicit.

What we'd rather ask for is all bytes in a string __preceded__ by a `\\` backslash, *or* any byte that is not a semicolon.

Regexes are such; not to be written by hand.

Given an array of strings `exprs` and an input string, we want to break the input down into `nterm` blocks separated by `term`, populating the array in the process, so that each element corresponds to a full expression.

`token` handles this process by taking a pointer to memory and matching it against our two patterns.

The `--re-consume` flag means `~=` match operator will `null` out the matched portion; thus, we must make copies. Each `re` holds a single capture stack of itself, thus we take the result and push it to `exprs`.

Now we know where each expression begins and ends; we can now walk down the array and break down the expressions individually to make subtrees.

## THE RELATION

Within the resulting hierarchy, individual values are to be found at the leaves; for each pass of a tree, different levels of name resolution are to be applied.

The very first one merely ensures all names within the document are declared and found, and only meant to provide a space for checks. But subsequent passes will begin value solving, which is not a simple topic to discuss.

Numbers would be the most straight-forward: for all strings matching either of the notations we allow, convert them to numerical values -- no context needed.

But symbols are different: a name could be a reference to an external, a local or global constant, a procedure, a data format, a pre-run definition or an alias. What's more, the final value of one branch might be dependant on another being solved first.

The idea of the pre-run `def` owes to this: these are build-time steps, not runtime. As such, they provide __textual subsitution__ in code. A `lis` is different in that it must reference a value known at runtime; generally, a shorthand for the sake of clarity.

## CONCLUSION

Runtime aliases exist to __avoid duplication of values when copying is not needed__; buildtime definitions are there to provide macro-like checks and tricks -- they are a hacker's tool.

Due to this, and even though they are too similar at first glance, there is greater value in having them both. Thus, I have decided against the deprecation of either.
