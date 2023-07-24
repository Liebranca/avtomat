#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD BYTES
# Bit hacking stravaganza
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd::Bytes;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    mchr
    mord
    lmord

    pastr
    xe

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# multi-byte ord
# won't go over a quadword

sub mord($str,%O) {

  # defaults
  $O{width}//=8;
  $O{elem_sz}//=64;
  $O{rev}//=1;

  $str=reverse $str if $O{rev};

  my $word = 0;
  my $b    = 0;

  for my $c(split $NULLSTR,$str) {

    $word |= ord($c) << $b;
    $b    += $O{width};

    last if $b == $O{elem_sz};

  };

  return $word;

};

# ---   *   ---   *   ---
# ^fixes that problem
# by handling you a quadword array ;>

sub lmord($str,%O) {

  # defaults
  $O{width}   //= 8;
  $O{elem_sz} //= 64;
  $O{rev}     //= 1;

  $str=reverse $str if $O{rev};

  my @words = ();
  my $b     = $O{elem_sz};

  # walk chars in str
  for my $c(split $NULLSTR,$str) {

    # elem is full, add new
    if($b == $O{elem_sz}) {
      push @words,0;
      $b=0;

    };

    # set bits and move to next char
    $words[-1] |= ord($c) << $b;
    $b         += $O{width};

  };

  return @words;

};

# ---   *   ---   *   ---
# multi-byte chr
# assumes array of quadwords

sub mchr($data,%O) {

  # defaults
  $O{width}   //= 8;
  $O{elem_sz} //= 64;
  $O{rev}     //= 0;
  $O{unprint} //= "\x{00}";

  @$data=reverse @$data if $O{rev};

  my $str  = $NULLSTR;
  my $word = shift @$data;

  my $b    = 0;
  my $mask = (1 << $O{width})-1;

  while($word || @$data) {

    # catch unprintable chars
    my $c=$word & $mask;
    $str.=($c < 0x20 || $c > 0x7E)
      ? $O{unprint}
      : chr($c)
      ;

    # move to next
    $word  = $word >> $O{width};
    $b    += $O{width};

    # element completed
    if($b == $O{elem_sz}) {
      $word=shift @$data;
      $b=0

    };

  };

  return $str;

};

# ---   *   ---   *   ---
# encodes strings the boring way

sub pastr($s,%O) {

  # default
  $O{size}  //= 'C';
  $O{width} //= 'C';

  my $len  = length $s;
  my @bs   = lmord($s,rev=>0,elem_sz=>8);

  my $fmat = "$O{size}$O{width}$len";

  return pack $fmat,$len,@bs;

};

# ---   *   ---   *   ---
# std hexdump printer

sub xe($bytes,%O) {

  $O{decode}  //= 1;

  $O{unprint} //= q[.];
  $O{catchar} //= "\n";

  $O{pad}     //= 2;
  $O{word}    //= 8;
  $O{line}    //= 2;

  my @accum = ();
  my @fmat  = ();

  my $me    = $NULLSTR;
  my $pad   = q[ ] x $O{pad};

  my $width = int(@$bytes);
  my $steps = int(($width/$O{word})+0.9999);

  # break down into words
  my $i=0;map {

    # set printf format for this word
    my $beg   = ($ARG+0)*$O{word};
    my $end   = ($ARG+1)*$O{word};
    my @ar    = @{$bytes}[$beg..$end-1];
       @accum = (@accum,@ar);

    map {$me.="%02X"} @ar;

    # EOL
    if(! (($i+1) % $O{line})) {
      $i  = -1;
      $me = "$me";

    # ^new line
    } elsif(! $i) {
      $me = "$pad$me ";

    # ^middle
    } else {
      $me = "$me ";

    };

    # ^catch EOL
    if($i < 0) {

      # optionally add chars matching bytes
      $me.=q[ | ].(join $NULLSTR,mchr(

        \@accum,

        elem_sz=>8,
        unprint=>$O{unprint},

      )) if $O{decode};

      push @fmat,$me;

      $me    = $NULLSTR;
      @accum = ();

    };

    $i++;

  } 0..$steps-1;

  # ^cat it all together
  $me=join $O{catchar},@fmat;
  return sprintf $me,@$bytes;

};

# ---   *   ---   *   ---
1; # ret
