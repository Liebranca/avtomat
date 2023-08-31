#!/usr/bin/perl
# ---   *   ---   *   ---

package Grammar::peso::hier;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar::peso::hier;
  use Grammar::peso::cdef;

# ---   *   ---   *   ---

my $prog=q[

reg A;

proc ins;

  blk input;

    def @T byte;
    ...;

    in @T str ibs;
    in @T str obs;


reg B;
  beq A;

proc ins;

  blk input;
    redef @T wide;

];

# ---   *   ---   *   ---
# ^parse and dbout

my $ice=Grammar::peso::hier->parse($prog);

map {
  $ice->hier_beq($ARG);

} @{$ice->{p3}->{leaves}};

map {
  $ice->hier_proc($ARG,'Grammar::peso::cdef');
  $ice->hier_prich($ARG);
say "_______________\n";

} @{$ice->{p3}->{leaves}};

# ---   *   ---   *   ---
1; # ret
