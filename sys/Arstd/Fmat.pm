#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD FMAT
# ~
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# NOTE:
#
# this used to be a bunch of sprintf wrappers
# now it does... more or less nothing
#
# it won't go away, but we'll dump functions
# related to it's original purpose here

# ---   *   ---   *   ---
# deps

package Arstd::Fmat;
  use v5.42.0;
  use strict;
  use warnings;

  use Perl::Tidy;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Style::null
    use Arstd::String::(cat linewrap);
    use Arstd::ansi::(ttysz);
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# perl tidy wrapper ;>

sub tidyup($sref,%O) {
  # defalts
  $O{columns} //= (ttysz)[0]-4;
  $O{filter}  //= 1;

  # call tidy
  my $out=null;
  Perl::Tidy::perltidy(
    source      => $sref,
    destination => \$out,
    argv        => [qw(
      -q
      -naws
      -i=2 -ci=2 -cti=0
      -pt=2 -sbt=2 -bt=2 -bbt=2

    ),"-l=$O{columns}"],
  );

  # ^cleanup and give
  linewrap(\$out,$O{columns});
  if($O{filter}) {
    $out=~ s/^(\s*\{)\s*/\n$1 /sgm;
    $out=~ s/(\}|\]|\));(?:\n|$)/\n\n$1;\n/sgm;
  };

  return $out;
};


# ---   *   ---   *   ---
1; # ret
