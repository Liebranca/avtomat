#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD FMAT
# sprintf on anabolic steroids
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

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


## ---   *   ---   *   ---
## apply format to string
#
#sub fstr($fmat,%O) {
#  # defaults
#  $O{args}      //= [];
#  $O{pre}       //= null;
#  $O{wrap}      //= [null,null];
#  $O{endtab}    //= null;
#  $O{pad}       //= 0;
#  $O{width}     //= (ttysz)[0];
#
#  # mark undefined
#  map {$ARG //= '<null>'} @{$O{args}};
#
#
#  # write args to fmat
#  sprintf $fmat,@{$O{args}};
#
#  # get line length for linewrapping
#  my $x     = $width-length($O{pre})-1;
#  my @lines = map {
#    $ARG="$O{pre}$ARG$O{endtab}\n"
#
#  } linewrap(\$body,$x);
#
#  push @lines,null if $O{pad};
#
#
#  # give final string
#  return cat($O{wrap}->[0],@lines,$O{wrap}->[1]);
#};


# ---   *   ---   *   ---
1; # ret
