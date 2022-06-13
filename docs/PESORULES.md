# WHAT IS PESO?

Four things:

0. A series of data estructure models for storing programs as bytecode strings.
1. A programming language designed around these structures.
2. If definition and translation tables are given, a common IR between languages.
3. A design philosophy; a programming paradigm unto itself.

# PESO RULES

The guiding principles are few and simple:

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
