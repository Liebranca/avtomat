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
  use List::Util qw(min);

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

    -icebox   => [],
    -autoload => [qw()],

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
  $O{pos}  //= 0;
  $O{par}  //= undef;

  # defined if taking pointer to base
  my $s     = $O{sref};
  my $frame = undef;

  # ^else make new base
  if(! $s &&! $O{par}) {

    # force size of base segment
    # to a multiple of UNIT_SZ
    $cap=
      int_urdiv($cap,$UNIT_SZ)
    * $UNIT_SZ
    ;

    # ^alloc
    $s     = \("\x{00}" x $cap);
    $frame = $class->new_frame();

  # ^pointer to base
  } else {
    $frame=$O{par}->{frame};

  };

  # make ice
  my $self=bless {

    id    => int(@{$frame->{-icebox}}),

    par   => $O{par},
    pos   => $O{pos},

    cap   => $cap,
    buf   => $s,

    tab   => {},
    div   => [],

    frame => $frame,

  },$class;

  push @{$frame->{-icebox}},$self;

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
  my @keys   = array_keys(\@segs);

  # make [name=>sub-segment]
  my @labels=map {

    # ^accum
    $offset  = $total;
    $total  += $segs{$ARG}->{cap};
    $bytes  .= ${$segs{$ARG}->{buf}};

    # ^ret [key=>value]
    $ARG   => [
      $offset,
      $segs{$ARG}->{cap}

    ];

  } @keys;

  # make ice
  my $self=$class->new($total);

  # ^populate
  $self->set(str=>$bytes);
  $self->put_labels(@labels);

  # subdivide segment tree
  for my $key(@keys) {

    my $info = $segs{$key};
    my $ptr  = $self->{tab}->{$key};

    $ptr->copy_labels($info);

  };

  return $self;

};

# ---   *   ---   *   ---
# get base segment from subseg

sub root($self,$depth=-1) {

  while($self->{par} && $depth != 0) {
    $self=$self->{par};
    $depth--;

  };

  return $self;

};

# ---   *   ---   *   ---
# get numerical indexes of seg

sub iof($self) {

  my $class = ref $self;

  my $frame = $class->iof_frame($self->{frame});
  my $addr  = $self->{id};

  return ($frame,$addr);

};

# ---   *   ---   *   ---
# pads value with zeroes to
# match size of segment

sub vpad($self,$s,%O) {

  # defaults
  $O{rev}   //= 0;
  $O{width} //= $self->{cap};

  my $len   = length $s;

  # get padding size
  my $diff  = $O{width} - $len;
     $diff *= $diff > 0;

  # ^put padding
  my $pad=("\x00" x $diff);
  $s=(! $O{rev})
    ? "$pad$s"
    : "$s$pad"
    ;

  return $s;

};

# ---   *   ---   *   ---
# converts numbers to bytes

sub xsized($self,$width,$raw) {

  my $s=mchr(

    [$raw],

    width   => $width,
    elem_sz => $width,
    noprint => 1,

    rev     => 1,

  );

  return $s;

};

# ---   *   ---   *   ---
# ^bat

sub array_xsized($self,$width,@raw) {
  return map {$self->xsized($width,$ARG)} @raw;

};

# ---   *   ---   *   ---
# write to segment

sub _set($self,$s) {
  ${$self->{buf}}=substr $s,0,$self->{cap};

};

# ---   *   ---   *   ---
# ^plain number

sub set_num($self,$raw) {

  # get chunk size
  my $width=min(64,$self->{cap}*8);

  # convert to bytestr and pad
  my $s=$self->xsized($width,$raw);
     $s=$self->vpad($s,rev=>1);

  $self->_set($s);

};

# ---   *   ---   *   ---
# ^non-reversed string

sub set_str($self,$raw) {

  my $s=reverse $raw;
     $s=$self->vpad($s,rev=>0);

  $self->_set($s);

};

# ---   *   ---   *   ---
# ^already reversed

sub set_rstr($self,$raw) {
  my $s=$self->vpad($raw,rev=>0);
  $self->_set($s);

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

  # update table
  push @{$self->{div}},$name=>$ptr;
  $self->{tab}->{$name}=$ptr;

  return $ptr;

};

# ---   *   ---   *   ---
# ^bat

sub put_labels($self,@labels) {

  my @names=array_keys(\@labels);
  my @sizes=array_values(\@labels);

  return map {

    my $name=$names[$ARG];
    my $args=$sizes[$ARG];

    $self->put_label($name,@$args);

  } 0..$#names;

};

# ---   *   ---   *   ---
# duplicate subdivisions recursively

sub copy_labels($self,$other) {

  my @names=array_keys($other->{div});
  my @sizes=array_values($other->{div});

  for my $key(@names) {

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

sub to_bytes($self,$width=undef) {

  $width//=8;

  return reverse lmord(

    ${$self->{buf}},

    width   => $width,
    elem_sz => $width,

    brev    => 1,

  );

};

# ---   *   ---   *   ---
# ^set buf from bytearray

sub from_bytes($self,$bytes,$width=undef) {

  $width//=8;

  my @ar=map {

    $self->vpad(

      $ARG,

      rev   => 0,
      width => int($width/8),

    );

  } $self->array_xsized(
    $width,reverse @$bytes

  );

  my $s=join $NULLSTR,reverse @ar;
  $self->set(rstr=>$s);

};

# ---   *   ---   *   ---
# debug out

sub prich($self,%O) {

  # defaults
  $O{errout} //= 0;

  # convert buf to hexdump
  my @bytes = reverse $self->to_bytes(64);
  my $me    = xe(\@bytes);

  # select
  my $fh=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  say {$fh} "$me\n";

};

# ---   *   ---   *   ---
1; # ret
