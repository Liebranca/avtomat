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

  use Grammar::peso::eye;

# ---   *   ---   *   ---

my $prog=q[{1}];

# ---   *   ---   *   ---
# ^parse and dbout

my ($eye)=Grammar::peso::eye->recurse($prog);

# ---   *   ---   *   ---
1; # ret
