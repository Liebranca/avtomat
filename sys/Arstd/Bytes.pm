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
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::Bytes;
  use v5.42.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;
  use Module::Load;

  use English;
  use List::Util qw(max min);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    $PACK_FMAT

    brev

    bitsize
    bitmask
    bitcat
    bitscanf
    bitscanr

    bitsume
    bitsumex

    bitsume_pack
    bitsume_unpack

    bytesize

    mchr
    mord
    lmord

    pastr
    xe

    machxe

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

  Readonly our $PACK_FMAT=>{
    8  => 'C',
    16 => 'S',
    32 => 'L',
    64 => 'Q',

  };

  Readonly our $BITOPS_LIMIT=>64;


# ---   *   ---   *   ---
# get bitsize of number

sub bitsize($x) {

  my $out=0;
  my $bit=1;
  my $set=0;

  while($x) {

    $set   = $bit * ($x & 1);
    $out   = ($set) ? $set : $out;

    $x   >>= 1;

    $bit++;

  };

  return (! $out) ? 1 : $out;

};


# ---   *   ---   *   ---
# ^get a bitmask for n number of bits

sub bitmask($x) {
  return (1 << $x)-1;

};


# ---   *   ---   *   ---
# cats bit fields to make str

sub bitcat(@elems) {

  # validate input
  !  (@elems % 2)
  or croak "Uneven arg count for bitcat";

  my $i     = 0;
  my $total = 0;

  my @str   = (0x00);

  # walk
  while(@elems) {

    # get [key => value]
    my $bits=shift @elems;
    my $size=shift @elems;

    $total+=$size;

    # get bits fit in current word
    my $step=$i+$size;

    # ^they dont, perform two writes
    if($step >= $BITOPS_LIMIT) {

      my $low  = $BITOPS_LIMIT - $i;
      my $high = $size  - $low;

      # first write:
      # whatever fits in current word
      $str[-1] |=
         ($bits & bitmask($low))
      << $i
      ;

      # ^go next
      push @str,0x00;

      # second write:
      # put leftovers in new word
      # set bit idex to end position
      $str[-1] |= $bits & bitmask($high);
      $i        = $high;

    # ^single write
    } else {

      $str[-1] |= $bits << $i;
      $i       += $size;

      # word is full, go next
      if($i == $BITOPS_LIMIT) {
        push @str,0x00;
        $i=0;

      };

    };

  };

  return mchr(

    \@str,

    rev     => 0,
    brev    => 0,
    noprint => 1,

  ),$total;

};


# ---   *   ---   *   ---
# bsf -- if you know, you know ;>

sub bitscanf($x) {

  my $idex=1;
  my $have=undef;

  while($x) {

    $have=$idex,last if $x & 1;

    $x >>= 1;
    $idex++;

  };


  return $have;

};


# ---   *   ---   *   ---
# ^bsr

sub bitscanr($x) {

  my $idex=64;
  my $have=undef;

  while($idex--) {
    $have=$idex,last if $x & (1 << $idex);

  };


  return $have;

};


# ---   *   ---   *   ---
# div bitsize by 8, rounded up

sub bytesize($x) {
  my $bits=bitsize $x;
  return int(($bits/8)+0.9999);

};


# ---   *   ---   *   ---
# open/close bytestr for reading

sub bitsume_pack($mem,%O) {

  $O{width} //= $BITOPS_LIMIT;

  return mchr(

    [@{$mem->{bytes}}],

    width   => min($BITOPS_LIMIT,$O{width}),

    brev    => 0,
    noprint => 1,

  );

};

sub bitsume_unpack($sref,%O) {

  $O{width} //= $BITOPS_LIMIT;

  my @bytes=lmord(

    $$sref,

    width => min($BITOPS_LIMIT,$O{width}),
    rev   => 0,

  );

  return {

    bit   => 0,
    bytes => \@bytes,

  };

};


# ---   *   ---   *   ---
# ^consume bits of bytestr
#
# guts v

sub bitsume($mem,@steps) {

  my @out   = ();

  my $bit   = \$mem->{bit};
  my $bytes = $mem->{bytes};

  my $old   = int @$bytes;

  for my $size(@steps) {

    # get bits fit in current word
    my $step=$$bit+$size;

    # ^they dont, perform two reads
    if($step > $BITOPS_LIMIT) {

      my $low  = $BITOPS_LIMIT - $$bit;
      my $high = $size  - $low;

      throw_oob_bit($$bit,$old-int @$bytes)
      unless defined $bytes->[0];

      # take first half
      my $x=$bytes->[0] & bitmask($low);
      shift @$bytes;

      throw_oob_bit($$bit,$old-int @$bytes)
      unless defined $bytes->[0];

      # ^join second with first
      $x|=
         ($bytes->[0] & bitmask($high))
      << $low
      ;

      push @out,$x;

      # substract bits and go next
      $bytes->[0] >>= $high;
      $$bit         = $high;

    # ^single read
    } else {

      throw_oob_bit($$bit,$old-int @$bytes)
      unless defined $bytes->[0];

      push @out,$bytes->[0] & bitmask($size);

      $bytes->[0] >>= $size;
      $$bit        += $size;

      # word is empty, go next
      if($$bit == $BITOPS_LIMIT) {
        shift @$bytes;
        $$bit=0;

      };


    };

  };

  return @out;

};


# ---   *   ---   *   ---
# ^crux

sub bitsumex($sref,@steps) {

  my $width = int((max(@steps)/8)+0.9999)*8;

  my $mem   = bitsume_unpack($sref,width=>$width);
  my @out   = bitsume($mem,@steps);

  $$sref=bitsume_pack($mem,width=>$width);

  return @out;

};


# ---   *   ---   *   ---
# ^errme for OOB reads

sub throw_oob_bit($i,$j) {

  # dynamically load in IO module to
  # avoid messing up build order
  state $class='Arstd::IO';
  load $class if ! $class->isa($class);

  # ^throw
  Arstd::IO::errout(

    q[Bit (:%u) of byte (:%u) ]
  . q[exceeds bytearray cap],

    lvl  => $AR_FATAL,
    args => [$i,$j],

  );

};


# ---   *   ---   *   ---
# byte-wise reversal
#
# ivs the byte ordering of each
# N-sized chunk in a string

sub brev($str,$step,$cnt) {

  my @chars = split null,$str;

  my $beg   = 0;
  my $end   = $step;

  return $str if @chars > $end;

  # generate [cnt] chunks
  # and join them
  my $out=join null,map {

    # take N-chars as individual chunk
    my $x=join null,@chars[$beg..$end-1];

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

  for my $c(split null,$str) {

    $word |= ord($c) << $b;
    $b    += $O{width};

    last if $b == $O{elem_sz};

  };

  return $word;

};


# ---   *   ---   *   ---
# ^fixes that problem
# by handing you an array ;>

sub lmord($str,%O) {

  # defaults
  $O{width}   //= 8;
  $O{elem_sz} //= 64;
  $O{rev}     //= 1;
  $O{brev}    //= 0;

  my @words = ();
  my $b     = $O{elem_sz};

  my $step  = int($O{width}/8);

  # get word count
  my $cnt   = int(
    ((length $str) / $step)
  + 0.9999

  );

  # conditional string reversal
  $str=reverse $str if $O{rev};

  # ^conditional *byte-wise* reversal
  $str=brev($str,$step,$cnt)
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
  my $str  = null;
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
  $str=brev($str,$step,$cnt)
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
  $O{drev}    //= 0;

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
  my $me    = null;
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
      my $asstr=null;
      $asstr.=(join null,mchr(

        \@accum,

        elem_sz => $O{word}*8,
        unprint => $O{unprint},

        rev     => 0,
        brev    => ! $O{drev},

      )).q[ | ] if $O{decode};

      # ^escape modulo for sprintf
      $asstr=~ s[$MODULO_RE][%%]sxmg;

      # ^save separately
      push @fmat,$me;
      push @xlate,$asstr;

      # ^clear
      $me    = null;
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
    $fmat[$ARG] . reverse $xlate[$ARG];

  } 0..$#xlate;

};


# ---   *   ---   *   ---
# ^"micro" form
#
# prints out two rows for a bytestr:
# * first row is each byte
# * second row is bits of each byte
#
# mostly used to inspect machine code ;>

sub machxe($s,%O) {

  # defaults
  $O{beg}   //= 0;
  $O{end}   //= 1;
  $O{line}  //= 4;

  my $out=null;

  # cut
  my $full = substr $s,$O{beg},$O{end};
  my $line = $O{line};

  my @ar   = split m[(.{1,$line})],$full;

  # do N chunks per line
  map {

    # ^walk bytes
    map {
      $out.=sprintf "%02X       ",ord($ARG)

    } split null,$ARG;

    $out.="\n";

    # ^walk bits
    map {
      $out.=sprintf "%08B ",ord($ARG)

    } split null,$ARG;

    $out.="\n";

  } @ar;

  # ^spit
  say $out;

};


# ---   *   ---   *   ---
1; # ret
