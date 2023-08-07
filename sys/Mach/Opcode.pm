#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH OPCODE
# Fcall to bytes
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::Opcode;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use List::Util qw(min max sum);
  use Module::Load;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::Re;

  use Arstd::IO;
  use Arstd::PM;

  use Mach::Seg;
  use Mach::Struc;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.7;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    -autoload=>[qw(
      add engrave encode_base regen

    )],

    -mach   => undef,
    -cstruc => [],

    -opidex => 0,
    -opsize => 0,
    -opbits => 0,

  }};

  Readonly our $REG_T=>0b001;
  Readonly our $MEM_T=>0b010;
  Readonly our $IMM_T=>0b100;

  Readonly our $SEG_T=>$MEM_T | $REG_T;

# ---   *   ---   *   ---
# generate descriptor for instruction
#
# guts v

sub new($class,$frame,$name,%O) {

  # operand types
  state $is_reg=qr{^\$reg};
  state $is_mem=qr{^\$mem};
  state $is_imm=qr{^\$imm};
  state $is_seg=qr{^\$seg};

  # ^fixed-sized operands
  state $imm_size=qr{
    $is_imm (?<size> [1-64])

  }x;

  state $mem_size=qr{

    $is_mem

    (?:

      (?<loc>  [1-32])
    y (?<addr> [1-32])

    | (?<solo> [1-32])

    )

  }x;

  # defaults
  $O{lis} //= $name;
  $O{pkg} //= caller;

  # instruction descriptor
  my $fn  = join q[::],$O{pkg},$name;
  my $out = {

    key   => $O{lis},

    id    => $frame->{-opidex}++,
    fn    => \&$fn,

    cnt   => 0,
    mode  => undef,

    arg_t => [],
    arg_s => [],

  };

  # get signature
  my @sig=argsof($O{pkg},$name);

  $out->{cnt}=int @sig;

  # ^det arg type && size from name
  for my $arg(@sig) {

    my $type=
      (int($arg=~ $is_reg) * $REG_T)
    | (int($arg=~ $is_mem) * $MEM_T)
    | (int($arg=~ $is_imm) * $IMM_T)
    | (int($arg=~ $is_seg) * $SEG_T)
    ;

    my $size=[];

    # register
    if($type eq $REG_T) {
      $size=[0];

    # ^fixed-size segment pointer
    } elsif($type eq $MEM_T && $arg=~ $mem_size) {

      $size=(! defined $+{solo})
        ? [$+{loc},$+{addr}]
        : [$+{solo},$+{solo}]
        ;

    # ^fixed-size immediate
    } elsif($type eq $IMM_T && $imm_size) {
      $size=[$+{size}];

    };

    push @{$out->{arg_t}},$type;
    push @{$out->{arg_s}},$size;

  };


  # det if mode bits are necessary
  my $mode=0;
  my $slow=0;

  # ^if only compat flags set, mode is fixed
  map {
    $mode |= $ARG - (1 *! $ARG)

  } @{$out->{arg_t}};

  # ^fixed, immediates
  if($mode == $IMM_T) {
    $mode=bitmask($out->{cnt});

  # ^fixed, memory or registers
  } elsif($mode && $mode <= $SEG_T) {
    $mode=0;

  # ^else mode must be encoded for
  # each variant of instruction
  } else {
    $mode=undef;

  };

  $out->{mode}=$mode;


  push @{$frame->{-cstruc}},$out;

};

# ---   *   ---   *   ---
# ^frame wraps

sub add($class,$frame,$name,%O) {
  $O{pkg}//=$frame->{-class};
  $class->new($frame,$name,%O);

};

# ---   *   ---   *   ---
# ^add instruction packages to table
#
# dynamically loads in package
# if required

sub engrave($class,$frame,@pkg) {

  map {
    load $ARG if ! $ARG->isa($ARG);
    $ARG->engrave($frame);

  } @pkg;

};

# ---   *   ---   *   ---
# transform descriptor to numerical repr

sub encode($self,$key,@args) {

  my $id   = $self->{base}->{$key};
  my $info = $self->{info}->{$id};

  # ^unpack
  my $cnt   = $info->{cnt};
  my $types = $info->{arg_t};
  my $sizes = $info->{arg_s};

  # check passed arguments match decl
  $cnt == int @args
  or throw_argcnt($key,$cnt,int @args);

  # encode args
  my @pack = ();
  my $mode = 0x00;
  my $i    = 0;

  for my $arg(@args) {

    my $x    = 0x00;

    my $type = $types->[$i];
    my $size = $sizes->[$i];

    my $seg  = Mach::Struc->validate($arg);

    # register/memory operand
    if($seg) {

      my $have=(exists $seg->{fast})
        ? $REG_T
        : $MEM_T
        ;

      # typechk
      ($have & $type) || (! $type)
      or throw_argtype($key,$i,$have,$type);

      push @pack,get_seg_width(
        $seg,$type,$size,$key,$i

      );

    # ^immediate
    } else {

      my $have=0b100;

      # typechk
      ($have eq $type) || (! $type)
      or throw_argtype($key,$i,$have,$type);

      $mode |= 1<<$i;

      push @pack,get_imm_width(
        $arg,$size,$key,$i

      );

    };

    $i++;

  };


  # skip mode bits if hardcoded
  my @hed=($id=>$self->{opbits});

  push @hed,$mode=>$cnt
  if ! defined $info->{mode};

  # run encoder
  return bitcat(@hed,@pack);

};

# ---   *   ---   *   ---
# ^handles fixed-width segment operands

sub get_seg_width($arg,$type,$size,$key,$i) {

  my @addr=@{$arg->{addr}};

  # drop the slow bit from the encoding
  # when segment type is known
  if(@$size || $type eq $MEM_T) {

    shift @addr;
    shift @addr;

    # in the case of a fixed-size
    # segment pointer, we also re-encode
    # it's address
    if(@$size && $type eq $MEM_T) {

      my ($alx,$aly)=@$size;

      @addr=($arg->encode_ptr(

        alx   => $alx,
        aly   => $aly,

        # these are just for debug
        fixed => "${alx}y${aly}",
        key   => $key,
        arg_i => $i,

      ) => $alx+$aly);

    };

  };

  return @addr;

};

# ---   *   ---   *   ---
# ^fixed-size immediates

sub get_imm_width($arg,$size,$key,$i) {

  my @out=();
  my $req=bitsize($arg);

  # width of immediate is hardcoded
  # for this instruction
  if(@$size) {

    my ($width)=@$size;

    throw_fixed_imm($key,$i,$arg,$width)
    if $req > $width;

    @out=($arg=>$width);

  # ^nope, must be encoded alongside
  # the value itself
  } else {

    my $width = max(8,$req);
       $width = int_align($width,8);
       $width = int_npow($width,2,1)-3;

    @out=(
      $width => 2,
      $arg   => 2**($width+3),

    );

  };


  return @out;

};

# ---   *   ---   *   ---
# ^errme for argument number

sub throw_argcnt($key,$cnt,$have) {

  errout(

    q[Invalid arg-count for '%s':]."\n"
  . q[have (:%u), expected (:%u)],

    lvl  => $AR_FATAL,
    args => [$key,$have,$cnt],

  );

};

# ---   *   ---   *   ---
# ^errme for arg type check

sub throw_argtype($key,$i,$type_a,$type_b) {

  state $tab={

    0b000=>'any',

    0b001=>'reg',
    0b010=>'mem',

    0b100=>'imm',

  };

  errout(

    q[Invalid type for arg ]
  . q[(:%u) of '%s':]."\n"

  . q[have [err]:%s, ]
  . q[expected [good]:%s],

    lvl  => $AR_FATAL,

    args => [

      $i,$key,

      "$tab->{$type_a}",
      "$tab->{$type_b}"

    ],

  );

};

# ---   *   ---   *   ---
# ^errme for immediate width mismatch

sub throw_fixed_imm($key,$i,$arg,$width) {

  errout(

    q[Invalid width for arg ]
  . q[(:%u) of '%s':]."\n"

  . q[Passed [err]:%s value for ]
  . q[a ptr of type [good]:%s],

    lvl  => $AR_FATAL,

    args => [

      $i,
      $key,

      bitsize($arg),
      "imm$width",

    ],

  );

};

# ---   *   ---   *   ---
# ^reads back instruction from mem

sub decode($self,$mem) {

  # unpack base
  my ($id)=bitsume($mem,$self->{opbits});

  # get argcount
  my $tab     = $self->{info}->{$id};
  my $cnt     = $tab->{cnt};

  # get arg types
  my $types = $tab->{arg_t};
  my $sizes = $tab->{arg_s};

  # skip mode bits if hardcoded
  my ($mode)=(! defined $tab->{mode})
    ? bitsume($mem,$cnt)
    : $tab->{mode}
    ;


  # ^walk args
  my @out = ();
  my $i   = 0;

  while($cnt) {

    my $type = $types->[$i];
    my $size = $sizes->[$i];

    my $imm  = $mode & 1;

    # immediate value
    if($imm) {
      push @out,rdimm($mem,$size);

    # memory operand
    } else {
      push @out,$self->rdseg($mem,$type,$size);

    };

    # go next
    $mode >>= 1;

    $cnt--;
    $i++;

  };


  # consume byte leftovers
  my $diff=int_align($mem->{bit},8);
     $diff=$diff - $mem->{bit};

  bitsume($mem,$diff) if $diff;

  # give bits read + decoded instruction
  unshift @out,$self->{info}->{$id}->{fn};
  return @out;

};

# ---   *   ---   *   ---
# read width of immediate
# then it's actual value

sub rdimm($mem,$size=[]) {

  my $width=0;

  # fixed-width
  if(@$size) {
    $width=$size->[0];

  # ^width inside instruction
  } else {
    ($width)=bitsume($mem,2);
    $width=2**($width+3);

  };

  return bitsume($mem,$width);

};

# ---   *   ---   *   ---
# ^read segment ptr

sub rdseg($self,$mem,$type,$size) {

  my $out  = undef;
  my $mach = $self->{frame}->{-mach};

  # skip slow bit if hardcoded
  my ($slow)=(! $type || $type eq $SEG_T)
    ? bitsume($mem,1)
    : $type eq $MEM_T
    ;

  # register or cache
  if(! $slow) {
    my ($addr)=bitsume($mem,$mach->{regmask});
    $out=$mach->segfetch($addr);

  # regular segment
  } else {
    my ($loc,$addr)=rdmem($mem,$size);
    $out=$mach->segfetch($loc,$addr);

  };

  return $out;

};

# ---   *   ---   *   ---
# ^read width of memory operand
# then it's actual value

sub rdmem($mem,$size=[]) {


  my ($loc,$addr)=(0x00,0x00);

  # fixed-width pointer
  if(@$size) {
    my ($x,$y)=@$size;
    ($loc,$addr)=bitsume($mem,$x,$y);

  # ^nope, must be read
  } else {

    my ($width)=bitsume($mem,3);
    $width=4+$width*4;

    my ($raw) = bitsume($mem,$width*2);
    my $mask  = bitmask($width);

    $loc  = $raw & $mask;
    $addr = $raw >> $width;

  };

  return ($loc,$addr);

};

# ---   *   ---   *   ---
# creates helper object
# from frame data

sub regen($class,$frame) {

  my $base = {};
  my $info = {};

  # width of instruction bits
  $frame->{-opbits}=bitsize(
    $frame->{-opidex}

  );

  # ^width of opcode base
  $frame->{-opsize}=int_align(
    $frame->{-opbits},8

  );

  my $opmask=bitmask($frame->{-opbits});

  # run through loaded descriptors
  my @keys=map {

    # pair [key  => base]
    # and  [base => info]
    $base->{$ARG->{key}} = $ARG->{id};
    $info->{$ARG->{id}} = {

      fn    => $ARG->{fn},
      cnt   => $ARG->{cnt},

      arg_t => $ARG->{arg_t},
      arg_s => $ARG->{arg_s},

      mode  => $ARG->{mode},

    };

    $ARG->{key};

  } @{$frame->{-cstruc}};

  # make ice
  my $out=bless {

    base   => $base,
    info   => $info,

    opbits => $frame->{-opbits},
    opsize => $frame->{-opsize},
    opmask => $opmask,

    # make pattern to detect
    # valid instructions
    re     => re_eiths(

      \@keys,

      bwrap   => 1,
      opscape => 1,

      insens  => -1,
      capt    => 'ins',

    ),

    frame  => $frame,

  },$class;

  return $out;

};

# ---   *   ---   *   ---
# read instructions from segment

sub read($self,$ptr) {

  my @out = ();
  my $mem = bitsume_unpack($ptr->{buf});

  # first byte set means
  # instruction in Q
  while($mem->{bytes}->[0]) {
    push @out,[$self->decode($mem)];

  };

  return @out;

};

# ---   *   ---   *   ---
# ^write to seg

sub write($self,$ptr,$ins,@args) {

  my ($opcode,$width)=$self->encode($ins,@args);

  $width=int_urdiv($width,8);

  $ptr->set(rstr=>$opcode);
  $ptr->brush($width,repl=>1);

};

# ---   *   ---   *   ---
1; # ret
