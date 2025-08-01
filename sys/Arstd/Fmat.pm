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

package Fmat;
  use v5.42.0;
  use strict;
  use warnings;

  use Perl::Tidy;
  use Carp qw(croak);

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Style::null
    use Arstd::String::(cat linewrap);

  );

  use Arstd::Path;


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
      -q -cb -nbl -sot -sct
      -blbc=1 -blbcl=* -mbl=1
      -i=2

    ),"-l=$O{width}"],

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
# apply format to string

sub fstr($fmat,%O) {

  # defaults
  $O{args}      //= [];
  $O{pre}       //= null;
  $O{wrap}      //= [null,null];
  $O{endtab}    //= null;
  $O{pad}       //= 0;
  $O{width}     //= (ttysz)[0];

  # mark undefined
  map {$ARG //= '<null>'} @{$O{args}};


  # write args to fmat
  sprintf $fmat,@{$O{args}};

  # get line length for linewrapping
  my $x     = $width-length($O{pre})-1;
  my @lines = map {
    $ARG="$O{pre}$ARG$O{endtab}\n"

  } linewrap(\$body,$x);

  push @lines,null if $O{pad};


  # give final string
  return cat($O{wrap}->[0],@lines,$O{wrap}->[1]);

};


# ---   *   ---   *   ---
# box-format string and output

sub box_fstrout($fmat,%O) {

  # opt defaults
  $O{args}      //= [];
  $O{errout}    //= 0;
  $O{no_print}  //= 0;
  $O{pre_fmat}  //= null;
  $O{post_fmat} //= null;
  $O{fill}      //= q{*};

  my $out=null;

  # dirty linewrap
  my $c     = $O{fill};
  my @ttysz = ttysz;

  # get length without escapes
  my $desc_c = ansi_descape($c);
  my $c_len  = length $desc_c;
  my $llen   = $ttysz[0]-($c_len*2)-3;

  # ^apply format
  my @lines=_fstrout_wrap($fmat,$llen,$O{args});

  # ^box it in
  map {
    $ARG=sprintf "$c %-${llen}s $c\n",$ARG

  } @lines;

  # get final string
  unshift @lines,
    ($c x ($ttysz[1]-1))."\n",
    sprintf "$c %-${llen}s $c\n",null;

  push @lines,
    (sprintf "$c %-${llen}s $c\n",null),
    ($c x ($ttysz[1]-1))."\n";

  $out=
    $O{pre_fmat}
  . (join null,@lines)

  . $O{post_fmat}
  ;

  # ^printing requested
  if(! $O{no_print}) {
    # select and spit
    my $fh=($O{errout})
      ? *STDERR
      : *STDOUT
      ;

    $out=print {$fh} $out;

  };

  return $out;

};


# ---   *   ---   *   ---
1; # ret
