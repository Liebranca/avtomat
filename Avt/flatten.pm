#!/usr/bin/perl
# ---   *   ---   *   ---
# FLATTEN
# flat assembler frontend
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::flatten;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Cwd qw(abs_path);
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

  use parent 'Shb7::Bk::front';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  return Shb7::Bk::front::new(

    $class,

    lang  => 'fasm',

    bk    => 'flat',
    entry => 'crux',
    flat  => 1,

    %O

  );

};

# ---   *   ---   *   ---
1; # ret
