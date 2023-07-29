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

  use Readonly;
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

  our $VERSION = v0.00.6;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $PACK_FMAT=>{
    8  => 'C',
    16 => 'S',
    32 => 'L',
    64 => 'Q',

  };

# ---   *   ---   *   ---
# byte-wise reversal
#
# ivs the byte ordering of each
# N-sized chunk in a string

sub bstr_reverse($str,$step,$cnt) {

  my @chars = split $NULLSTR,$str;

  my $beg   = 0;
  my $end   = $step;

  # generate [cnt] chunks
  # and join them
  my $out=join $NULLSTR,map {

    # take N-chars as individual chunk
    my $x=join $NULLSTR,@chars[$beg..$end-1];

    # go next
    $beg += $step;
    $end += $step;

    # ^reverse chunk
    $x=reverse $x;
    $x;

  } 0..$cnt-1;

  return $out;

};

# ---   *   ---   *   ---
# multi-byte ord
# won't go over a quadword

sub mord($str,%O) {

  # defaults
  $O{width}   //= 8;
  $O{elem_sz} //= 64;
  $O{rev}     //= 1;

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
# by handling you an array ;>

sub lmord($str,%O) {

  # defaults
  $O{width}   //= 8;
  $O{elem_sz} //= 64;
  $O{rev}     //= 1;
  $O{brev}    //= 0;

  my @words = ();
  my $b     = $O{elem_sz};

  my $step  = int($O{elem_sz}/8);

  # get word count
  my $cnt   = int(
    ((length $str) / $step)
  + 0.9999

  );

  # conditional string reversal
  $str=reverse $str if $O{rev};

  # ^conditional *byte-wise* reversal
  $str=bstr_reverse($str,$step,$cnt)
  if $O{brev};

  # make format for splitting string
  my $fmat=$PACK_FMAT->{$O{width}};
     $fmat=$fmat x $cnt;

  # ^walk split chars
  for my $c(unpack $fmat,$str) {

    # elem is full, add new
    if($b == $O{elem_sz}) {

      push @words,0;
      $b=0;

    };

    # set bits and move to next char
    $words[-1] |= $c << $b;
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
  $O{brev}    //= 0;
  $O{unprint} //= "\x{00}";
  $O{noprint} //= 0;

  @$data=reverse @$data if $O{rev};

  my $fmat = $PACK_FMAT->{$O{width}};
  my $str  = $NULLSTR;
  my $word = shift @$data;

  my $b    = 0;
  my $mask = (1 << $O{width})-1;

  while(defined $word) {

    # catch unprintable chars
    my $c  = $word & $mask;
    my $up = $c < 0x20 || $c > 0x7E;

    $str.=($up &&! $O{noprint})
      ? $O{unprint}
      : pack $fmat,$c
      ;

    # move to next
    $word  = $word >> $O{width};
    $b    += $O{width};

    # element completed
    if($b == $O{elem_sz}) {
      $word = shift @$data;
      $b    = 0;

    };

  };

  my $step  = int($O{elem_sz}/8);

  # get word count
  my $cnt   = int(
    ((length $str) / $step)
  + 0.9999

  );

  # ^conditional *byte-wise* reversal
  $str=bstr_reverse($str,$step,$cnt)
  if $O{brev};

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

  my @accum  = ();
  my @fmat   = ();
  my @xlate  = ();
  my @chunks = ();

  my $zcnt  = $O{word} * 2;
  my $me    = $NULLSTR;
  my $pad   = q[ ] x $O{pad};

  my $width = int(@$bytes);

  # break down into X words per strline
  my $i=0;map {

    # set printf format for this word
    push @accum,$bytes->[$ARG];
    $me.="%0${zcnt}X";

    # EOL
    if(! (($i+1) % $O{line})) {

      push @chunks,$i;

      $i  = -1;
      $me = "$me";

    # ^new line
    } elsif(! $i) {
      $me = "$pad$me ";

    # ^middle
    } else {
      $me = "$me ";

    };

    # ^catch EOL|EOF
    if($i < 0 || $ARG == $width-1) {

      push @chunks,$i if ! ($i < 0);

      # optionally add chars matching bytes
      my $asstr=$NULLSTR;
      $asstr.=q[ | ].(join $NULLSTR,mchr(

        \@accum,

        elem_sz => $O{word}*8,
        unprint => $O{unprint},

        rev     => 1,
        brev    => 1,

      )) if $O{decode};

      # ^escape modulo for sprintf
      $asstr=~ s[$MODULO_RE][%%]sxmg;

      # ^save separately
      push @fmat,$me;
      push @xlate,$asstr;

      # ^clear
      $me    = $NULLSTR;
      @accum = ();

    };

    $i++;

  } 0..$width-1;

  # ^apply formats
  my @bt=reverse @$bytes;
  $i=0;@fmat=map {

    my $chunk=shift @chunks;

    my $s=sprintf
      $ARG,@bt[$i..$i+$chunk];

    $i+=$O{line};
    $s;

  } @fmat;

  # uneff byte ordering
  @xlate=reverse @xlate;

  # ^cat it all together
  return join$O{catchar},map {
    $fmat[$ARG] . $xlate[$ARG];

  } 0..$#xlate;

};

# ---   *   ---   *   ---
1; # ret
