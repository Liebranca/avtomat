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
# lyeb,

# ---   *   ---   *   ---
# deps

package Emit::fasm;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Fmat;

  use Arstd::Path;
  use Arstd::Array;

  use Shb7::Path;
  use Shb7::Build;

  use Tree;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Emit::Std;

  use parent 'Emit';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

# ---   *   ---   *   ---
# file prologue

sub boiler_open($class,$fname,%O) {

  state $imphed=q[

; ---   *   ---   *   ---
; get importer

if ~ defined loaded?Imp
  include '%ARPATH%/forge/Imp.inc'

end if

; ---   *   ---   *   ---
; deps

];

  # get load order
  my $i    = 0;
  my $ldo  = $O{ldo};

  # ^stirr
  my $imps = join $NULLSTR,map {

    my $lib=$ldo->[($ARG*2)+0];
    my $inc=$ldo->[($ARG*2)+1];

    "library $lib\n" . (join "\n",map {
      "  use $ARG"

    } @$inc)

    . "\n\nimport\n\n"
    ;

  } 0..(@$ldo/2)-1;


  # TODO: settable format
  my $fmat=
    "format ELF64 executable 3\n"
  . "entry _start"
  ;

  my $out="$fmat$imphed$imps";

  return $out;

};

# ---   *   ---   *   ---
# ^epilogue

sub boiler_close($class,$fname,%O) {

  return join "\n",

    "\n\n; ---   *   ---   *   ---",
    "; cruxwraps\n",

    "align \$10",
    "_start:",
    "  call $O{entry}",
    "  exit",

  ;

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

    my $s     = ($line=~ m[^\s])
      ? ' '
      : $NULLSTR
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
          : $NULLSTR
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

        $t //= $NULLSTR;
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
