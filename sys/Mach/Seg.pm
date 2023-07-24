#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH SEG(-ment)
# Piece of mem
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::Seg;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::Array;
  use Arstd::IO;

  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PESZ);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# shut up, I target 64-bit

BEGIN {

  $SIG{__WARN__}=sub {
    my $warn=shift;
    return if $warn=~ m[non-portable];

    warn $warn;

  };

};

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    -autoload=>[qw()],

  }};

  Readonly my $UNIT_SZ => int(16);

  Readonly my $BYTE_SZ => int($UNIT_SZ/$UNIT_SZ);
  Readonly my $WORD_SZ => int($UNIT_SZ/2);

  Readonly my $WIDE_SZ => int($WORD_SZ/4);
  Readonly my $BRAD_SZ => int($WORD_SZ/2);

  Readonly my $HALF_SZ => int($UNIT_SZ*2);
  Readonly my $LINE_SZ => int($UNIT_SZ*4);

  Readonly my $PAGE_SZ => int($UNIT_SZ*64);

  # ^as table
  Readonly our $PESZ   => {

    byte=>$BYTE_SZ,
    wide=>$WIDE_SZ,
    brad=>$BRAD_SZ,
    word=>$WORD_SZ,

    unit=>$UNIT_SZ,
    half=>$HALF_SZ,
    line=>$LINE_SZ,
    page=>$PAGE_SZ,

  };

# ---   *   ---   *   ---
# GBL

  our $Icebox;

# ---   *   ---   *   ---
# cstruc

sub new($class,$cap,%O) {

  # defaults
  $O{pos} //= 0;
  $O{par} //= undef;

  # defined if taking pointer to base
  my $s=$O{sref};

  # ^else make new base
  if(! $s) {

    # force size of base segment
    # to a multiple of UNIT_SZ
    $cap=
      int_urdiv($cap,$UNIT_SZ)
    * $UNIT_SZ
    ;

    # ^alloc
    $s=\("\x{00}" x $cap);

  };

  # make ice
  my $self=bless {

    par => $O{par},
    pos => $O{pos},

    cap => $cap,
    buf => $s,

    tab => {},

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# ^shallow copy of existing

sub cpy($self) {

  my $class = ref $self;
  my $cpy   = bless {%{$self}},$class;

  return $cpy;

};

# ---   *   ---   *   ---
# merge segments into new

sub cat($class,@segs) {

  my $total  = 0;
  my $offset = 0;
  my $bytes  = $NULLSTR;

  my %segs   = @segs;

  # make [name=>sub-segment]
  my %labels=map {

    # ^accum
    $offset  = $total;
    $total  += $segs{$ARG}->{cap};
    $bytes  .= ${$segs{$ARG}->{buf}};

    # ^ret [key=>value]
    $ARG   => [
      $offset,
      $segs{$ARG}->{cap}

    ];

  } array_keys(\@segs);

  # make ice
  my $self=$class->new($total);

  # ^populate
  $self->set(str=>$bytes);
  $self->put_labels(%labels);

  # subdivide segment tree
  my @pending=values %segs;
  for my $key(keys %segs) {

    my $info = $segs{$key};
    my $ptr  = $self->{tab}->{$key};

    $ptr->copy_labels($info);

  };

  return $self;

};

# ---   *   ---   *   ---
# write to segment

sub _set($self,$s) {

  my $len   = length $s;
  my $cap   = $self->{cap};

  # get padding size
  my $diff  = $cap - $len;
     $diff *= $diff > 0;

  # ^put padding
  $s=("\x00" x $diff) . $s;

  # ^write up to cap bytes
  ${$self->{buf}}=substr $s,0,$cap;

};

# ---   *   ---   *   ---
# ^type converters

sub set_num($self,$raw) {

  my @bytes=();

  # ^convert to byte array
  while($raw) {
    my $b=sprintf "%02X",$raw & 0xFF;
    push @bytes,eval(q["].'\x{'.$b.'}'.q["]);

    $raw >>= 8;

  };

  # ^commit
  my $s=join $NULLSTR,reverse @bytes;
  $self->_set($s);

};

# ---   *   ---   *   ---
# ^no transform

sub set_str($self,$raw) {
  $self->_set($raw);

};

# ---   *   ---   *   ---
# ^crux

sub set($self,%O) {

  my ($type) = keys %O;
  my $value  = $O{$type};

  my $f      = "set_$type";

  $self->$f($value);

};

# ---   *   ---   *   ---
# take reference to a sub-segment

sub point($self,$offset,$width) {

  my $req=$offset+$width;

  errout(

    q[Ptr exceeds segment capacity; ]
  . q[offset '$%02X' out of bounds],

    lvl  => $AR_FATAL,
    args => [$req],

  ) unless $req <= $self->{cap};

  # reference section of seg
  my $sref  = \(substr

    ${$self->{buf}},

    $offset,
    $width

  );

  # ^make subseg
  my $class = ref $self;
  my $ptr   = $class->new(

    $width,

    pos  => $offset,
    sref => $sref,

    par  => $self,

  );

  return $ptr;

};

# ---   *   ---   *   ---
# ^store named reference

sub put_label($self,$name,$offset,$width) {

  my $ptr=$self->point($offset,$width);
  $self->{tab}->{$name}=$ptr;

  return $ptr;

};

# ---   *   ---   *   ---
# ^bat

sub put_labels($self,%labels) {

  return map {
    my $data=$labels{$ARG};
    $self->put_label($ARG,@$data);

  } keys %labels;

};

# ---   *   ---   *   ---
# duplicate subdivisions recursively

sub copy_labels($self,$other) {

  for my $key(keys %{$other->{tab}}) {

    my $info = $other->{tab}->{$key};
    my $ptr  = $self->put_label(

      $key,

      $info->{pos},
      $info->{cap}

    );

    $ptr->copy_labels($info);

  };

};

# ---   *   ---   *   ---
# ptr++
sub inc($self,$step=1) {

  errout(

    q[Base segment cannot be moved; ]
  . q[use a ptr],

    lvl=>$AR_FATAL,

  ) unless defined $self->{par};

  # prohibit OOB
  my $limit=$self->{par}->{cap};

  $step  = $step*$self->{cap};
  $step *=
    ($step < 0)
  * (($self->{pos}+$step) >= 0)

  + ($step > 0)
  * (($self->{pos}+$step) <= $limit)
  ;

  # ^set new position and overwrite
  my $pos=$self->{pos}+$step;

  %$self=%{$self->{par}->point(
    $pos,$self->{cap}

  )};

};

# ---   *   ---   *   ---
# ^iv

sub dec($self,$step=1) {
  $self->inc(-$step);

};

# ---   *   ---   *   ---
# get buf as a bytearray

sub to_bytes($self) {

  return lmord(

    ${$self->{buf}},

    width   => 8,
    elem_sz => 8,
    rev     => 0,

  );

};

# ---   *   ---   *   ---
# debug out

sub prich($self,%O) {

  # defaults
  $O{errout} //= 0;

  state $fmat=
    q[  ]
  . (join q[ ],(("%02X" x 8) x 2))
  ;

  # convert buf to hexdump
  my @bytes= $self->to_bytes();

  my $cnt  = @bytes;
  my $diff = ($cnt % $UNIT_SZ)
    ? (int_urdiv($cnt,$UNIT_SZ) * $UNIT_SZ) - $cnt
    : 0
    ;

  push @bytes,(0) x $diff;
  my $me=xe(\@bytes);

  # select
  my $fh=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  say {$fh} "$me\n";

};

# ---   *   ---   *   ---
1; # ret
