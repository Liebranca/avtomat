### v3.22.0

- Remembered this file existed and promptly flooded this entry with all the big changes I could remember.

- `rm`'d things you people wouldn't believe.

- Initial implementation of a virtual machine in `A9M`, a parser in `rd`, and a peso assembler/interpreter in `ipret`.

- Halfway deprecation of `Mach`, `Lang`, `Grammar` and `Emit`; "halfway" because we are still working on a proper replacement, which would be the triad `rd`, `ipret` and the yet-to-be `xlate`. `A9M` is in it's infancy but already a full replacement and improvement for `Mach`.

- Myriad updates to the base class `St` which, in short, is our "OOP" framework (in less than 400 SLOC ;>). Classes derived from `St` now have access to virtual constants, `Frame` tuning, static caches and callbacks for some standard methods, among other things.

- Added `id`, `Icebox` modules for handling both instances of `Frame`-less classes as well as instance containers (see: icebox ;>) of classes that *do* use `Frame`.

- Implemented further `Tree` methods for matching node sequences. Fixed a few mistakes in the node insertion and replacement methods. Instances within the same container now guaranteed to have a `-uid` unique ID.

- Completely overhauled `Type` to be a little bit closer to x86 assembly, which was the original intent anyway, since it's driving the bulk of our FFI mambo. 

- The `pack` and `unpack` wrappers in `Type` were moved to their own module, `Bpack`. This is coupled with `Bitformat` and `FF` modules for handling raw structures and binary files.

- Added utilities for generating command-line wrappers of perl packages.

- Added a "compile and run" option to `olink`. Implemented support for building fasm projects through `Avt::flatten`; moved C-specific build code to `Avt::CRun`.

### v3.21.7

- First partreim of peso through an `%lpsrom`.
- Grammar::OR fixes

### v3.21.6

- Added the `Tree::Grammar` class; it provides a baseline implementation for Raku-inspired grammars.
- Initial implementation of micro syntax files generation through `sygen`.
- Basic execution in parse trees, for the reworked `peso/lps`.
- Added the `Grammar` base class to simplify language definitions.
- Added `Grammar` docfile.
- Upped the peso bootstrap layers from one to two.

### v3.21.5

- Initial `side_build` implementations for `Avt::Sieve` and `Makescript`.
- Added `Avt::Bfile` package for managing intermediate files. Whereas before the file lists were managed as a plain string array, now it's been object-fied and made more general.
- Major `Shb7` cleanup; it's now broken up into various submodules.
- Install files now take `utils` hashes for building single-source apps; compilation of these is handled separately, but using the same methods as the rest of the project.

### v3.21.4

- Added this file ;>
- Added `Avt::Sieve` package, tasked with reading file lists from config into Makescript.
- Cleanup of `get_config_files`; it's still a bit repetitive by nature, but at least now it's easier to add file lists and hashes to the config struct.
