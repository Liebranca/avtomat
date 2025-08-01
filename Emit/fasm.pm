#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT FASM
# speaks aramaic...
# like el masi7 ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Emit::fasm;
  use v5.42.0;
  use strict;
  use warnings;

  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

  use Arstd::Path qw(parof fname_to_pkg);
  use Shb7::Path qw(shpath);

  use lib "$ENV{ARPATH}/lib/";
  use Emit::Std;

  use parent 'Emit';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# file prologue

sub boiler_open($class,$fname,%O) {

  state $imphed=join "\n",(
    q[; ---   *   ---   *   ---],
    q[; get importer],

    q[if ~ defined loaded?Imp],
    q[  include '%ARPATH%/forge/Imp.inc'],

    q[end if],

    q[; ---   *   ---   *   ---],
    q[; deps],

  ) . "\n";


  # get load order
  my $i   = 0;
  my $ldo = $O{ldo};

  # ^stirr
  my $imps=catar map {
    my $lib=$ldo->[($ARG*2)+0];
    my $inc=$ldo->[($ARG*2)+1];

    join "\n",(
      "library $lib",
      (map {
        "  use $ARG"

      } @$inc),

      "import"

    );

  } 0..(@$ldo/2)-1;


  # TODO: settable format
  my $fmat=join "\n",(
    q[format ELF64 executable 3],
  . q[entry _start],

  );

  my $out="$fmat$imphed$imps";

  return $out;

};


# ---   *   ---   *   ---
# ^epilogue

sub boiler_close($class,$fname,%O) {
  return join "\n",(
    q[; ---   *   ---   *   ---],
    q[; cruxwraps],

    q[align $10],
    q[_start:],
    "  call $O{entry}",
    q[  exit],

  );

};


# ---   *   ---   *   ---
# placeholder: code formatting

sub tidy($class,$sref) {
  state $re=qr{(?<!\\)\n};

  my @lines = split $re,$$sref;

  my @beg   = ();
  my @len   = ();
  my @tok   = ();
  my @max   = map {0} 0..16;

  for my $line(@lines) {
    my @blank = split m[[^\s]+],$line;
    my @token = split $NSPACE_RE,$line;

    my $s=($line=~ m[^\s])
      ? ' '
      : null
      ;


    if(length $s) {
      push @len,0;

      map {
        my $x=length $token[$ARG];
        $max[$ARG]=$x if $x > length $max[$ARG];

      } 0..$#token;

    } else {
      push @len,\@blank;

    };

    push @beg,$s;
    push @tok,\@token;

  };

  for my $line(@lines) {
    my $beg = shift @beg;
    my $len = shift @len;
    my $tok = shift @tok;

    my $s   = $beg;
    my $i   = 0;

    if(! $len) {
      map {
        my $l=$max[$i++]+1;
        my $b=$l-(length $ARG);

        $b=($b > 0)
          ? ' ' x $b
          : null
          ;


        $s.="$ARG$b";

      } @$tok;


    } else {
      while(@$tok || @$len) {

        my $t=shift @$tok;
        my $b=shift @$len;

        $b   = (! length $b)
          ? ' '
          : $b
          ;

        $t //= null;
        $s  .= "$t$b";

      };

    };

    $s=~ s[\s+$][];
    $line=$s;

  };


  return join "\n",@lines;

};


# ---   *   ---   *   ---
# derive package name from
# name of file

sub get_pkg($class,$fname) {
  my $dir=parof($fname);
  return fname_to_pkg($fname,shpath($dir));

};


# ---   *   ---   *   ---
1; # ret
