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

At a high level, we could say that the job of a parser is mapping strings to trees. But the task itself is better understood when broken down into small processing steps, which we call *stages*, each consisting of smaller data transforms.

The default stages are `parse`, `preproc`, and `reparse`. We'll begin with `parse` and come back to the other two in future sections.


For the most part, `parse` relies on three layers: `l0`, `l1` and `l2`, that deal with characters, tokens and token-trees, respectively. Here's a brief overview of them all:

### L0

Maps input characters to methods; it will read the string input of `rd` char by char, and associate that input to a specific state mutation.

If layers require any kind of association between a particular character and another piece of data, said transform should be carried out by `l0`.

It's responsibilities are as follows:

- `csume`: shifting the next input character from the source string.

- `cat`: concatenate the input to the current token.

- `charset`: associate a character to a method. Characters not in this table are associated to `cat`.

- `spchars`: a plain list of special characters.

- `read`: `csume` and pass the received input character to `charset`, then invoke the returned method.

- `flagset`: activate or deactivate switches that affect how certain input characters are handled.

- `flagchk`: read the value of said switches.

- `store`: push the current state to stack.

- `load`: pop from the stack.

- `commit`: save the current token.

- `discard`: throw away the token.

- `term`: terminate the current expression.

- `enter`: mark the beggining of a nested expression within the current one.

- `leave`: mark the end of such a nested expression.


### L1

Performs a two-way mapping of raw tokens, ie ones without typing information, to typed tokens.

As in the previous case, `token => data` associations are carried out by `l1`. We make but one exception to this rule: `l0` itself can decide on the type of a token before pushing it.

Following from this, `l1` is at full liberty of establishing a `token => method` table. We'll take advantage of this in the later stages.

As for responsibilities:

- `tag`: add typing data to an untyped token.

- `untag` and `xlate`: undo the previous step; `untag` will give a representation of the token in internal format, whereas `xlate` returns a human-readable version.

- `typechk`: check that a token matches a specific type.

- `switch`: walk a `type => F` array and return `call F` if `typechk type`.

- `cat`: join two tokens of the same type.

- `detect`: match the value of a raw token to a type and `tag` said token. If a typed token is passed, return it as-is.

- `extend`: add a new token type to the internal tables.


### L2

Analyses sequences of tokens, ie expressions, that are represented as trees, then decides on transforms to the tree structure based on this analysis.

For the better part, `l2` works by reading the type data of tokens into an array, then comparing that to a list of *signatures* that denote the valid combinations of tokens that make up a certain kind of expression.

Similarly to the previous layers, `signature => data` associations are carried out by `l2`, and `data` in this case *also* includes invocation of methods; we'll see more of this once we get to `preproc`.

The `l2` responsibilities are:

- `cat`: push a token to the current expression.

- `term`, `enter` and `leave`: same as `l0`.

- `define`: associate a sequence of tokens to a method.
- `invoke`: look for a set of sequences within a branch and execute the associated method for each sequence found.

- `walk` and `recurse`: iter through the nodes of a branch and `invoke` a set of sequences of each; `recurse` saves the state of the current `walk`, and then starts a new one.


### ALL TOGETHER

The `parse` stage thus proceeds as follows:

- String or file passed to `rd`.

- The contents of said input are read by `l0`.

- On token `commit`, `l1` detects it's type and pushes it to the current expression.

- On expression `term`, `l2` starts a new expression.


As previously mentioned, the very first expression is processed early to determine if any mutations of the base class must be carried out; processing of all other expressions is delayed until later stages.

This process repeats until the entirety of the input has been consumed, after which a 'raw' parse tree is returned.


## PROCESSING EXPRESSIONS

Before jumping in to the following stages, let us take a moment to discuss a wider topic that concerns all of them: transforming and interpreting the parse tree.

First, a brief definition: 'tree', in this case, stands for a hierarchy of tokens which we utilize to represent both a sequence of values and the relationships between them.

As an example, one way to break down the expression `T N=X+Y` is `(= (T (N)) (+ (X Y)))`, or a more illustrative form such as:

```$

=
\-->T
.  \-->N
.
\-->+
.  \-->X
.  \-->Y

```

Where `=` is the parent of `(T +)`, `T` is the parent of `N`, `+` is the parent of `(X Y)`, and so on; there is a strict hierarchical relationship between these tokens, and in order to perform any meaningful analysis of any such sequence, these relationships need to be accounted for.

Let's say that through `l2` we establish the following rules, sorted by priority:

- `T => SYM`: a keyword `T` followed by a symbol corresponds to a variable or constant declaration; parent `SYM` to `T`.

- `ANY => '+' => ANY`: a single `+` plus sign between any two tokens denotes adding two values; parent both tokens to `+`.

- `ANY => '=' => ANY`: a single `=` equals sign between any two tokens denotes value assignment; parent both tokens to `=`.


Given the parse tree `(T N = X + Y)`, we could process the expression as such:

- `T => SYM` is higher in priority, and thus is matched first. From `(T N = ...)` we obtain `((T (N)) = ...)`.

- `ANY => '+' => ANY` follows in priority. Applying the rule, we transform `(... = X + Y)` into `(... = (+ (X Y)))`.

- `ANY => '=' => ANY` is last; `T` and `+` are parented to `=`, and thus we end with `(= (T (N)) (+ (X Y)))`.


To visualize the process a bit better, we can draw it like so:

```$

# initial expression

(EXP)
.
\-->T
\-->N
.
\-->=
.
\-->X
\-->+
\-->Y


# apply first rule (T => SYM)

(EXP)
.
\-->T
.  \-->N
.
\-->=
.
\-->X
\-->+
\-->Y


# apply second rule (ANY => '+' => ANY)

(EXP)
.
\-->T
.  \-->N
.
\-->=
.
\-->+
.  \-->X
.  \-->Y


# apply final rule (ANY => '=' => ANY)

(EXP)
.
\-->=
.  \-->T
.  .  \-->N
.
.  \-->+
.  .  \-->X
.  .  \-->Y

```

The resulting tree then represents the __precise order of operations__; there is a relationship between the assignment and it's two children, because __the assignment cannot be performed until both it's arguments are solved__. In other words, the result of `=` is *dependent* on the individual results of `(T +)`.

Without getting too ahead of ourselves, as solving this kind of operation within a tree is `ipret` territory, we can note that just as the rules we applied to transform the tree, each of these __sub-expressions__ ought to behave, by itself, as a function.

This isn't so obvious with the syntax rules themselves, as we simply defined nodes to be matched and a transform to the current expression using those nodes, but the exact same mechanism is utilized to detail how branches of the tree are later interpreted -- suffice to say we are not limited to modifying *just* the parse tree.

(TO BE CONTINUED... )
