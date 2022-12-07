# v3.21.5

- Initial `side_build` implementations for `Avt::Sieve` and `Makescript`.
- Added `Avt::Bfile` package for managing intermediate files. Whereas before the file lists were managed as a plain string array, now it's been object-fied and made more general.
- Major `Shb7` cleanup; it's now broken up into various submodules.
- Install files now take `utils` hashes for building single-source apps; compilation of these is handled separately, but using the same methods as the rest of the project.

# v3.21.4

- Added this file ;>
- Added `Avt::Sieve` package, tasked with reading file lists from config into Makescript.
- Cleanup of `get_config_files`; it's still a bit repetitive by nature, but at least now it's easier to add file lists and hashes to the config struct.
