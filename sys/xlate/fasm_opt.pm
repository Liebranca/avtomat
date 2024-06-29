#!/usr/bin/perl
# ---   *   ---   *   ---
# XLATE FASM OPT
# Simple x86 optimizations
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS,
# lyeb,

# ---   *   ---   *   ---
# deps

package xlate::fasm_opt;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match_vars);

  use lib "$ENV{ARPATH}/avtomat/sys/";

  use Style;
  use Type;

  use Arstd::Int;
  use Arstd::Bytes;
  use Arstd::IO;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    fxpreci
    fxpdiv
    fxpmod

    leamul

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# mul by lea: first attempt

sub leamul_step1($y,$s,$need) {


  # map opera to instruction
  my $exp=int_npow2 $s,1;
  my $tab={

    "$y+$y*$s" => [lea=>(

      {type=>'r',reg=>'X'},

      { type  => 'mlea',
        rX    => 'X',
        rY    => 'X',

        scale => $exp,

      },

    )],

    "0+$y*$s"  => [lea=>(

      {type=>'r',reg=>'X'},

      { type  => 'mlea',
        rX    => 'X',
        scale => $exp,

      },

    )],

  };


  # ^walk
  my @out=();
  map {

    my $res=eval $ARG;

    # stop if single will do
    return ($res,$tab->{$ARG})
    if $res == $need;


    # else give full table
    push @out,$res,$tab->{$ARG};


  } keys %$tab;

  return @out;

};

# ---   *   ---   *   ---
# mul by lea: second attempt

sub leamul_step2($n,$y,$s,$need) {


  # map opera to instruction
  my $exp=int_npow2 $s,1;
  my $tab={

    "$n+$n*$s" => [lea=>(

      {type=>'r',reg=>'X'},

      { type  => 'mlea',
        rX    => 'Y',
        rY    => 'Y',

        scale => $exp,

      },

    )],

    "$n+$y*$s" => [lea=>(

      {type=>'r',reg=>'X'},

      { type  => 'mlea',
        rX    => 'Y',
        rY    => 'X',

        scale => $exp,

      },

    )],

    "$y+$y*$s" => [lea=>(

      {type=>'r',reg=>'X'},

      { type  => 'mlea',
        rX    => 'X',
        rY    => 'X',

        scale => $exp,

      },

    )],

    "$y+$n*$s" => [lea=>(

      {type=>'r',reg=>'X'},

      { type  => 'mlea',
        rX    => 'X',
        rY    => 'Y',

        scale => $exp,

      },

    )],

    "0+$n*$s"  => [lea=>(

      {type=>'r',reg=>'X'},

      { type  => 'mlea',
        rX    => 'Y',

        scale => $exp,

      },

    )],

    "0+$y*$s"  => [lea=>(

      {type=>'r',reg=>'X'},

      { type  => 'mlea',
        rX    => 'X',

        scale => $exp,

      },

    )],

    "$n"       => null,
    "$y"       => null,

  };


  map {

    my $res=eval $ARG;

    # stop if two ops will do
    return $tab->{$ARG}
    if $res == $need;

  } keys %$tab;


  # else fail!
  return undef;

};

# ---   *   ---   *   ---
# multiply by non-pow2 using lea
# imul on fail ;>

sub leamul($n,$f) {


  # f is pow2?
  my $p2 = int_npow2 $f,1;
  if((1 << $p2) == $f) {

    return ($n << $p2,[shl=>(
      {type=>'r',reg=>'Y'},
      {type=>'i',imm=>$p2},

    )]);

  };


  # ^nope, do it the hard way ;>
  my @scale = (2,4,8);
  my @ins   = ();

  my $x     = 0;
  my $need  = $n*$f;


  # walk first row
  for my $s0(@scale) {


    # single op does it?
    my @combo=leamul_step1 $n,$s0,$need;
    if(@combo == 2) {
      $x   = shift @combo;
      @ins = shift @combo;

      last;

    };


    # ^nope, walk second row...
    for my $idex(0..1) {

      my $y    = $combo[$idex*2+0];
      my $ins  = $combo[$idex*2+1];

      for my $s1(@scale) {


        # stop if two ops does it!
        my $have = leamul_step2 $n,$y,$s1,$need;

        if(defined $have) {
          @ins = ($ins,$have);
          $x   = $need;

          last;

        };

      };

      last if $x;

    };


    last if $x;

  };


  # give imul if X wasn't solved
  return ($x == 0)

    ? (

      $need,[mov=>(
        {type=>'r',reg=>'Z'},
        {type=>'i',imm=>$f},

      )],[imul=>(
        {type=>'r',reg=>'X'},
        {type=>'r',reg=>'Z'},

      )],

    ) : ($need,@ins) ;

};

# ---   *   ---   *   ---
# fixed point division by
# multiplication
#
# ie black flippin' magic

sub fxpreci($f,$bits) {
  return int (((1<<$bits) + $f-1) / $f);

};

sub fxpdiv($n,$f,$bits=0) {


  # f is pow2?
  my $p2=int_npow2 $f,1;
  if((1 << $p2) == $f) {
    return ($n >> $p2,[shr=>(
      {type=>'r',reg=>'Y'},
      {type=>'i',imm=>$p2},

    )]);

  };


  # ^nope, do it the hard way ;>
  $bits=4+bitsize $n if ! $bits;

  my $rc  = fxpreci($f,$bits);
  my @ins = (

    [mov=>(
      {type=>'r',reg=>'Y'},
      {type=>'r',reg=>'X'},

    )],

    [mov=>(
      {type=>'r',reg=>'X'},
      {type=>'i',imm=>$rc},

    )],

    [imul=>(
      {type=>'r',reg=>'X'},
      {type=>'r',reg=>'Y'},

    )],

    [shr=>(
      {type=>'r',reg=>'X'},
      {type=>'i',imm=>$bits},

    )],

  );

  return (($n * $rc) >> $bits,@ins);

};

# ---   *   ---   *   ---
# ^fixed point modulo

sub fxpmod($n,$f,$bits=0) {


  # f is pow2?
  my $p2  = int_npow2 $f,1;
  if((1 << $p2) == $f) {
    my $mask=$f-1;
    return ($n & $mask,[and=>(
      {type=>'r',reg=>'Y'},
      {type=>'i',imm=>$mask},

    )]);

  };


  # ^nope, do it the hard way ;>
  $bits=4+bitsize $n if ! $bits;

  my ($x,@insa) = fxpdiv $n,$f,$bits;
  my ($y,@insb) = leamul $x,$f;

  my @ins=(@insa,@insb,

    [sub=>(
      {type=>'r',reg=>'Y'},
      {type=>'r',reg=>'X'},

    )],

    [mov=>(
      {type=>'r',reg=>'X'},
      {type=>'r',reg=>'Y'},

    )],

  );

  return ($n-$y,@ins);

};

# ---   *   ---   *   ---
# placeholder: replace register name

sub regrepl($src) {

  my @r=grep {defined $$ARG} (

    \$src->{reg},

    \$src->{rX},
    \$src->{rY},

  );

  map {

    $$ARG={
      'X'=>0,
      'Y'=>4,
      'Z'=>6,

    }->{$$ARG};

    $$ARG++ if $src->{type} eq 'mlea';

  } @r;

  return;

};

# ---   *   ---   *   ---
# unroll peso modulo

sub expand_mod($self,$type,$ins,@args) {

  my @have=$self->operand_value($type,@args);

  if($have[-1] =~ $NUM_RE) {

    my $next=typefet {
      byte  => 'word',
      word  => 'dword',
      dword => 'qword',
      qword => 'qword',

    }->{$type->{name}};


    my $bits       = 4+$type->{sizebs};
    my ($n,@exins) = fxpmod
      $have[-1],$have[-1],$bits;

    map {

      my ($ins,@nargs)=@$ARG;
      map {regrepl $ARG} @nargs;

      my $type=($ins eq 'lea')
        ? typefet 'dword'
        : $type
        ;

      ($ins=~ qr{^(?:mov|mul|imul|shr|shl)})
        ? unshift @$ARG,$next
        : unshift @$ARG,$type
        ;

    } @exins;


    return @exins;

  } else {
    nyi "NON-CONST MOD";

  };

};

# ---   *   ---   *   ---
# unroll peso rand

sub expand_rand($self,$type,$ins,@args) {

  $type=typefet 'qword';

  return (

    [$type,'rdtsc'],

    [$type,'shl',
      {type=>'r',reg=>6},
      {type=>'i',imm=>32},

    ],

    [$type,'or',
      {type=>'r',reg=>0},
      {type=>'r',reg=>6},

    ],

  );

};

# ---   *   ---   *   ---
1; # ret
