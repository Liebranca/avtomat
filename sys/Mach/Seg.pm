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
  use List::Util qw(min max);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::Array;
  use Arstd::Re;
  use Arstd::IO;

  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PESZ $PESIGN $PEREAL);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.7;#b
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

    -id       => 0,
    -mach     => [],
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
  Readonly our $PESZ=>{

    byte  => $BYTE_SZ,
    wide  => $WIDE_SZ,
    brad  => $BRAD_SZ,
    word  => $WORD_SZ,

    sbyte => $BYTE_SZ,
    swide => $WIDE_SZ,
    sbrad => $BRAD_SZ,
    sword => $WORD_SZ,

    real  => $BRAD_SZ,
    daut  => $WORD_SZ,

    unit  => $UNIT_SZ,
    half  => $HALF_SZ,
    line  => $LINE_SZ,
    page  => $PAGE_SZ,

  };

  Readonly our $PESIGN=>qr{(?:
    sbyte | swide | sbrad | sword

  )}x;

  Readonly our $PEREAL=>qr{(?:real|daut)};

# ---   *   ---   *   ---
# cstruc

sub new($class,$cap,%O) {

  # defaults
  $O{pos}  //= 0;
  $O{par}  //= undef;
  $O{fast} //= undef;
  $O{mach} //= undef;

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
    $frame = $O{mach}->new_baseg();

  # ^pointer to base
  } else {
    $frame=$O{par}->{frame};

  };

  # make ice
  my $self=bless {

    addr  => $NULL,

    par   => $O{par},
    pos   => $O{pos},

    cap   => $cap,
    buf   => $s,

    tab   => {},
    div   => [],

    frame => $frame,

  },$class;


  # ^catch incomplete frame
  exists $frame->{-mach}
  or throw_no_mach($self);

  # ^register ice
  $self->assign_fast() if $O{fast};
  $self->calc_addr();

  return $self;

};

# ---   *   ---   *   ---
# assigns unique identifier to segment,
# in a frame-independent manner;
#
# ie, addr without loc
#
# note that "fast" is an euphemism
# for "treat it as a register or cache"
#
# although the unique id provides
# a somewhat  faster way to fetch
# the segment ref, it's just as slow
# as a regular segment would be for
# reads and writes

sub assign_fast($self) {

  my $frame = $self->{frame};
  my $mach  = $frame->{-mach};

  # add segment to reg/cache list
  my $fast=$mach->{fast_seg};

  $self->{fast}=int @$fast;
  push @$fast,$self;

};

# ---   *   ---   *   ---
# ^cache numerical repr

sub calc_addr($self) {

  # catch incomplete frame
  my $frame = $self->{frame};
  my $mach  = $frame->{-mach};

  my @elems = ();
  my $slow  = 0;


  # short form avail (register or cache)
  if(exists $self->{fast}) {
    @elems=($self->{fast} => $mach->{regmask});

  # ^regular memory operand, use long form
  } else {

    # store self
    my $icebox = $frame->{-icebox};
    my $loc    = $frame->{-id};
    my $addr   = int @$icebox;

    push @$icebox,$self;

    $self->{slow}=[$loc,$addr];

    # get addr
    my ($width,$value)=$self->encode_ptr();

    # [bits => bitsize]
    @elems=(

      $width => 3,
      $value => (4+$width*4)*2,

    );

    $slow=1;

  };


  # ^save field list
  unshift @elems,$slow=>1;
  $self->{addr}=\@elems;

};

# ---   *   ---   *   ---
# warn of bad init

sub throw_no_mach($self) {

  my $class = ref $self;
  my $fn    = (caller 2)[3];

  my $frame = $self->{frame};
  my $id    = $frame->{-id};

  errout(

    q[[ctl]:%s <%s>;] . "\n\n"

  . q[Segment frame $(:%08X) lacks a ]
  . q[[goodtag]:%s reference],

    lvl  => $AR_FATAL,
    args => ['IRUPT',$fn,$class,$id],

  );

};

# ---   *   ---   *   ---
# encodes a segment pointer

sub encode_ptr($self,%O) {

  # defaults
  $O{alx}   //= 4;
  $O{aly}   //= 4;
  $O{fixed} //= 0;

  my @out    = ();
  my $frame  = $self->{frame};

  # get base indices
  my ($loc,$addr)=@{$self->{slow}};

  # get widths as multiple of alignment
  my $locw  = get_ptr_w($loc,$O{alx},%O);
  my $addrw = get_ptr_w($addr,$O{aly},%O);

  # ^encode using largest
  if($O{alx} == $O{aly}) {

    my $width = max($locw,$addrw);
    my $step  = (! $O{fixed})
      ? $O{alx} + $width * $O{alx}
      : $width
      ;

    my $value = $loc | ($addr << $step);

    # ^width dropped from encoding
    # when ptr size is fixed
    @out=(! $O{fixed})
      ? ($width,$value)
      : ($value)
      ;

  # ^use both widths
  } elsif($O{fixed}) {
    @out=($loc | ($addr << $locw));

  # ^bad encoding passed
  } else {
    throw_ptrenc($O{alx},$O{aly});

  };


  return @out;

};

# ---   *   ---   *   ---
# ^quick shorthand for getting width

sub get_ptr_w($addr,$align,%O) {

  my $req=bitsize($addr);

  throw_fixed_width($req,%O)
  if $O{fixed} && $req > $align;

  my $addrw=max($align,$req);

  return (! $O{fixed})
    ? int_align($addrw,$align)-$align
    : $addrw
    ;

};

# ---   *   ---   *   ---
# ^errme for width mismatch

sub throw_fixed_width($req,%O) {

  errout(

    q[Invalid width for arg ]
  . q[(:%u) of '%s':]."\n"

  . q[Passed [err]:%s value for ]
  . q[a ptr of type [good]:%s],

    lvl  => $AR_FATAL,

    args => [

      $O{arg_i},
      $O{key},

      "${req}-bit",
      "mem$O{fixed}",

    ],

  );

};

# ---   *   ---   *   ---
# ^errme for bogus encodings

sub throw_ptrenc($alx,$aly) {

  errout(

    q[Ptr of type [good]:%s must ]
  . q[be fixed-size],

    lvl  => $AR_FATAL,
    args => ["mem${alx}y${aly}"],

  );

};

# ---   *   ---   *   ---
# shallow copy of existing

sub cpy($self) {

  my $class = ref $self;
  my $cpy   = bless {%{$self}},$class;

  return $cpy;

};

# ---   *   ---   *   ---
# merge segments into new

sub cat($class,$mach,@segs) {

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
  my $self=$class->new($total,mach=>$mach);

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

    brev    => 1,
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
     $s=$self->vpad($s,rev=>0);

  $self->_set($s);

};

# ---   *   ---   *   ---
# ^non-reversed string

sub set_str($self,$raw) {

  my $s=reverse $raw;
     $s=$self->vpad($s,rev=>1);

  $self->_set($s);

};

# ---   *   ---   *   ---
# ^already reversed

sub set_rstr($self,$raw) {
  my $s=$self->vpad($raw,rev=>1);
  $self->_set($s);

};

# ---   *   ---   *   ---
# ^seg-to-seg
# cats write to self size

sub set_seg($self,$other) {
  $self->_set(${$other->{buf}});

};

# ---   *   ---   *   ---
# ^stores seg addr

sub set_ptr($self,$other) {

  my ($loc,$addr)=($other->{fast})
    ? ($other->{fast})
    : @{$other->{slow}}
    ;

  $self->set(num=>$addr | ($loc << 32));

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
# get un-reversed buf as a string

sub get_str($self) {

  my $s=${$self->{buf}};
  $s=~ s[$UNPRINT_RE][]sxmg;

  return $s;

};

# ---   *   ---   *   ---
# ^reversed

sub get_rstr($self) {
  return reverse $self->get_str();

};

# ---   *   ---   *   ---
# ^to_bytes alternative

sub get($self) {

  my $width = min(8,$self->{cap});
  my @steps = map {
    $width*8

  } 0..int_urdiv($self->{cap},$width)-1;

  my $s=reverse ${$self->{buf}};

  return bitsumex(\$s,@steps);

};

# ---   *   ---   *   ---
# take reference to a sub-segment

sub point($self,$offset,$width,%O) {

  my $req=$offset+$width;

  errout(

    q[[good]:%s exceeds segment capacity;] . "\n"
  . q[offset $(:%04X) out of bounds],

    lvl  => $AR_FATAL,
    args => ['ptr',$req],

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

    $width,%O,

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
# gives pointer to whole segment,
# substracting offset from size

sub brush($self,$offset=0,%O) {

  # defaults
  $O{repl} //= 0;

  # make ice
  my $width = $self->{cap} - $offset;
  my $ptr   = $self->point($offset,$width);

  # ^optionally replace self for new
  %$self=%$ptr if $O{repl};

  return $ptr;

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
