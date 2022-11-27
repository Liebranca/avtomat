# v3.21.5 (WIP)

- Initial `side_build` implementations for `Avt::Sieve` and `Makescript`.
- Added `Avt::Bfile` package for managing intermediate files. Whereas before the file lists were managed as a plain string array, now it's been object-fied and made more general.

# v3.21.4

- Added this file ;>
- Added `Avt::Sieve` package, tasked with reading file lists from config into Makescript.
- Cleanup of `get_config_files`; it's still a bit repetitive by nature, but at least now it's easier to add file lists and hashes to the config struct.
