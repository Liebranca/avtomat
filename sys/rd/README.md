# RD: HOLY PARSER

## SYNOPSIS

Theory crafting, formal descriptions, and brief guides to hacking the `AR/` parser model.


## BASIC STRUCTURE

`rd` is divided into layers: but this division is, for the better part, merely conceptual. In truth, it is a __single  class__ that loads subclasses and delegates tasks to them.

It is the instances of these subclasses that we call "layers", while the parser itself is internally referred to as `main`. Each layer encapsulates more or less a singular type of data transform, and can freely refer to `main`, and thus to other layers, to handle different tasks.

There's two purposes behind this: first, for plain division of concerns and code reuse, but second and more importantly, to allow for easier mutation of the base class. This way, `rd` is both a parser *and* a skeleton from which parsers and interpreters can be built.

This is achieved in a simple manner, inspired by the Unix `#!` shebang: the first __expression__ of any piece of code must follow a base syntax, and within this expression, the desired mutation is declared.

Uppon parsing that first expression, `rd` will load any new subclasses and replace the corresponding layers. After this point, the parser has been effectively mutated into another class, and so the rest of the file is processed according to new syntax rules.

Once parsing is completed, an `rd` instance can be mutated again to obtain an interpreter; however, this division between reading and executing code is also conceptual, and done only to avoid confusion -- `rd` has interpreter capabilities on it's own as a consequence of the structures and methods it implements, but is not *meant* to be used as such.

Thus, the interpreter phase is handled separately by a derived class (see: `sys/ipret/`), that reutilizes the relevant parser layers on top of adding new ones. We will not go into details of the interpreter implementation in this document, but since `rd` and `ipret` are essentially two moments in the lifecycle of the same object, mention of the interpreter is simply inevitable.

## FIRST STAGE

At a high level, we could say that the job of a parser is mapping strings to trees. But the task itself is better understood when broken down into small processing steps, which we call *stages*.

The default stages are `parse`, `preproc`, and `reparse`. We'll begin with `parse` and come back to the other two in the next section.


For the most part, `parse` relies on only two layers: `l0` and `l1`, that deal with characters and tokens, respectively.

`l0` will read the string input of `rd` char by char. It's responsibilities are as follows:

- `csume`: shifting the next input character from the source string.

- `read`: `csume` and branch off based on the input character received.

- `cat`: concatenate the input to the current token.

- `commit`: save the current token.

- `discard`: throw away the token.

- `flag`: activate or deactivate a switch that affects how the next input character(s) should be handled.

- `enter`: mark the beggining of a nested expression within the current one.

- `leave`: mark the end of such a nested expression.

- `term`: terminate the current expression.


When `l0` chooses to `commit` a token, `l1` processes it based on it's internal criteria, and then pushes the processed token to the current branch on the parse tree.

Then, when `l0` chooses to `term` an expression, `main` will move on from this branch and generate a new one. If the nesting level is non-zero, this new branch is parented to the corresponding expression.

This process repeats until `FATAL` is encountered or the entire source string is succesfully read. Once there are no more input characters, `rd` will terminate the current expression and mark the stage as finished.


## IN-BETWEEN

Before we discuss `l1` in detail, let us take a moment to talk about an important background concept.

Because at this point, we would hope that all tokens in the tree are classified. But how can we identify all tokens correctly, when we still haven't built any context data beyond the parse tree?

The answer is we cannot: combined, `l0` and `l1` can only recognize simple patterns, such as special characters or the notation for numbers and strings: everything else is just a __symbol__, which in this context, simply means a name that serves as representation for some data.

Each symbol, or sequence of symbols, could be the name of a value, or the name of a function, or an instruction to the parser... or it could also be a preprocessor directive, that's meant to expand to another thing entirely!

But we still don't know, for no such definitions have even been loaded. This scenario, of encountering yet-unsolvable unknowns that we must still work with, is the single, most recurring, most important problem.

Because the question is, very much, the waltzaround that ought to be carried out for dealing with __undefined__ data. But this is not a matter of computer science or mathematics but rather one of human reasoning, which nobody understands and no algorithm can replace -- algorithms themselves are, by their very nature, quantizations of human reasoning, and therefore not a replacement.

What I mean to convey through this tangent is that there is no solution to be found in the present, and so we are left without much better option than making assumptions about a possible future, that if realized, should confirm that we indeed assumed correctly.

At `AR/`, we name this `CVYC`, pronounced "cee-vic", more or less as in "civics": it stands for __clairvoyance__ or __clairvoyant code__. When we say that `rd` is a `cvyc chain`, what we mean to say is that it works, fundamentally, as a series of processes that output predictions about the nature of undefined data into one another.

This, in practice, is mercifully not quite as convoluted as the theory might lead you to believe. Because we know beforehand -- and for a fact -- that *if* the code is syntactically correct, and *if* every step in the chain is succesful in performing it's share of the data processing, that the unknown will eventually be solved... *if* such a solution exists!

We'll come back to `CVYC` soon enough; for now, this is sufficient to understand the next section.

## TOKEN TYPES && SEQUENCES

We can break down the responsibilities of `l1` as follows:

- `tag`: add typing data to an untyped token.

- `untag`: undo the previous step.

- `typechk`: check that a token matches a specific type.

- `switch`: walk a `type => F` array and return `call F` if `chktag type`.

- `cat`: join two tokens of the same type.


But just *what* are these "types"? In short, additional characters added to a token which denote a loose classification, one that we can later use to recognize the exact semantics of a token in a given context.

But whereas `l0` has virtually no undefinedness to deal with due to it merely reading characters from an input string with no hard unknowns, `l1` cannot be so straight forward due to the indefinite meanings that are possible for different kinds of symbols or combinations thereof, as we briefly discussed in the previous section.

So during the first stage, there is not much classification we can do! For now, we'll content ourselves with correctly identifying four base types:

- `OPR`: special characters.

- `STR`: raw, variable length bytearray.

- `NUM`: any token that matches some specific numerical notation.

- `SYM`: none of the above.


In addition to these, `l1` accepts requests for the generation of three "group" types:

- `EXP`: a full expression within a scope; the beggining of any expression between `enter` and `leave` is represented as an `EXP` token.

- `SCP`: a scope generated by `enter`, to which `EXP` tokens are parented to.

- `LIST`: tokens of any type separated by the `LIST` operator (`,` comma by default).


However, note that we are not *permanently* limited to these basic types: more can be added as we progress to later stages and build context data.

(TO BE CONTINUED... )
