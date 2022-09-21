# CAREFUL

Work-in-progress document *is* a work in progress.

# PREAMBLE

Avtomat generalizes parsing of programming languages in order to handle reading and emitting code; this is why it can generate syntax highlighting and FFI binding files.

However, while the syntaxes of certain languages are similar enough, there's always an edge case. This means the operation can only be generalized to a certain degree; for each language with special syntax rules, these special cases need to be punched by hand.

This document aims to explain the process by which, in theory, the software can be expanded to work with any other language besides C.

# THE LANG MODULE

Each language can be broken up into syntax rules, represented by a `Lang::Def`; these are a collection of keywords, operators and patterns. A full list of these can be found in the `<Lang/Def.pm>` file under `%DEFAULTS`. The following fields are of special importance:

```perl

delimiters=>[
  '('=>')','PARENS',
  '['=>']','BRACKET',
  '{'=>'}','CURLY',

],

foldtags=>[qw(
  chars strings

)],


```

These are used to "tokenize" complex expressions. For instance, wrapping a segment of code around `{}` curly brackets typically indicates that it is an individual block with it's own scope; it can be broken down at a later stage of execution utilizing the same rules as the rest of the file, one step at a time.

However, because it might mean something entirely different in certain languages, or in different contexts within the same language, the parser does not attempt to make sense of it straight away: it simply stores the contents of the block and pushes a unique `cut_token` to the parse tree.

This token can be then expanded into it's original definition, once the context is fully known, and then properly analyzed.

`Lang` by itself does nothing but provide a container for these first-pass rules.

# RD

The core of the parser the aptly named `<hacks/Shwl.pm>` file, which contains the `codefold` subroutine. It will look for common patterns such as type or function declarations and store them as their own separate block. The `Rd` itself contains these blocks and their respective parse trees.

What `codefold` does is replace these patterns for unique tokens, as previously mentioned. It does this operation for an entire file or string. The procedure call it uses to achieve this goes as such:

```perl

sub extract(

  $body_ref,

  $re,
  $cut_key,
  $cut_alias,

  $lang

) {

```

Where `$body_ref` is a reference to a string, `$re` is the pattern to match and the `$cut_key,$cut_alias` duo are used to generate the tokens that the main tree will see. `$lang` is an instance of `Lang::Def` containing the definitions of any necessary additional patterns.

The `Peso::Rd::parse` procedure invokes `codefold` on a file or string using the patterns in the provided language definition to "cut" up the tree into blocks, and returns an instance of the `Peso::Rd` class. This `$rd` object can perform the following operations as needed:

- `select_block` sets the current block for all following operations.

- `recurse` takes a tree-node of the current block and expands it recursively. The contents of the resulting branches are tokenized in Peso order:

```$

0: cut token
1: keyword
2: label

3: operators

4: version strings
5: hierarchicals
6: symbol

7: number
8: scope terminator

9: unrecognized

```

Where the very first token in the sequence, and every other token until an expression terminator (the `exp_bound` field of a language definition) will be parented to it.

- `replstr` takes a node-tree removes cut tokens of the `foldtags` cathegory, meant to be used with literals, and replaces them with their actual values.

- `fn_search` and `utype_search` look for branches matching the function and type definition patterns set by the language rules.

With these utilities, rough parse trees can be quickly generated.

# TREES

As previously mentioned, parsing can only be generalized so much. This is why the `<sys/Tree.pm>` file contains so many methods for quickly finding and reorganizing nodes. It's expansion via the `Tree::Syntax` class also includes some further methods that utilize a tree's language definition, among them the `tokenize` call itself that `$rd->recurse` uses.

Here's a quick overview of the more useful methods:

- `branch_in` returns the *first* node in the tree that matches a given pattern. The `branches_in` variant returns *all* nodes that match.

- `branch_with` functions similarly, except it returns the first node in the tree that has an immediate child that matches the provided pattern. `branches_with`, again, returns the entire list of matches.

- `pushlv` parents a list of nodes to another. If the nodes are already parented, they are removed from the previous parent.

- `insert` moves a list of nodes to a given position within another node's leaves.

- `dup` creates a copy of an entire branch, ie a node and all it's children.

- `pluck` removes a list of nodes from a branch.

- `repl` replaces one node with another. `deep_repl` ensures copying of all attributes -- only of use for duplicated branches.

- `flatten_branch` inserts a node's leaves into it's parent's leaves, optionally consuming the head (root) of the branch.

- `leafless` gives a list of nodes in the tree that do not have children.

- `hasleaves` does the inverse; a list of nodes that have children.

- `match_from` looks in a branch starting at a given node up to another that matches a given pattern, and returns the match.

- `match_until` does the same, but it returns the entire list of nodes *up* to the match. Optionally, it can omit the closing node.

- `leaves_between` gives a list of all children nodes in a branch, from index `a+1` to index `b`.

Finally, the `prich` method prints out a drawing of the structure for debugging purposes.

The `Tree::Syntax` class adds, among other things, the following methods:

- `subdiv` breaks expressions down according to an operator table; a full working example of such tables is avail at `<Peso/Ops.pm>`. This methods guarantees that operations with higher priority are lower in the hierarchy.

- `collapse` solves operations according to the operator table in a subdivided tree. Operations that are lower in the hierarchy are solved first.

