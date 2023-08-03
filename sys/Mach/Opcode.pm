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
  use Arstd::IO;
  use Arstd::PM;

  use Mach::Seg;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    -autoload=>[qw(
      add engrave encode_base regen

    )],

    -cstruc=>[],

    -opidex=>0,
    -opsize=>0,
    -opbits=>0,

  }};

# ---   *   ---   *   ---
# generate descriptor for instruction
#
# guts v

sub new($class,$frame,$name,%O) {

  state $is_reg=qr{\$reg};
  state $is_mem=qr{\$mem};
  state $is_imm=qr{\$imm};

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

    arg_t => [],

  };

  # get signature
  my @sig=argsof($O{pkg},$name);

  # ^det arg type from name
  for my $arg(@sig) {

    push @{$out->{arg_t}},
      (int($arg=~ $is_reg) << 0)
    | (int($arg=~ $is_mem) << 1)
    | (int($arg=~ $is_imm) << 2)
    ;

  };

  $out->{cnt}=int @sig;

  push @{$frame->{-cstruc}},$out;

};

# ---   *   ---   *   ---
# ^frame wraps

sub add($class,$frame,$name,%O) {
  $O{pkg}//=$frame->{-class};
  $class->new($frame,$name,%O);

};

# ---   *   ---   *   ---
# ^add instruction package to table

sub engrave($class,$frame,$pkg) {

  load $pkg if ! $pkg->isa($pkg);
  $pkg->engrave($frame);

};

# ---   *   ---   *   ---
# transform descriptor to numerical repr

sub encode($self,$key,@args) {

  my $id   = $self->{base}->{$key};
  my $info = $self->{info}->{$id};

  # ^unpack
  my $cnt   = $info->{cnt};
  my $types = $info->{arg_t};

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

    # register/memory operand
    if(Mach::Seg->is_valid($arg)) {

      my $have=(exists $arg->{fast})
        ? 0b001
        : 0b010
        ;

      # typechk
      ($have eq $type) || (! $type)
      or throw_argtype($key,$i,$have,$type);

      push @pack,@{$arg->{addr}};

    # ^immediate
    } else {

      my $have=0b100;

      # typechk
      ($have eq $type) || (! $type)
      or throw_argtype($key,$i,$have,$type);

      $mode |= 1<<$i;

      my $width = max(8,bitsize($arg));
         $width = int_npow($width,2,1)-3;

      push @pack,(
        $width => 2,
        $arg   => 2**($width+3),

      );

    };

    $i++;

  };

  # run encoder
  unshift @pack,(

    $id   => $self->{opbits},
    $mode => $cnt,

  );

  return bitcat(@pack);

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

    0b000=>'reg,mem or imm',

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

      $tab->{$type_a},
      $tab->{$type_b}

    ],

  );

};

# ---   *   ---   *   ---
# ^reads back instruction from mem

sub decode($self,$mem) {

  # unpack base
  my ($id)=bitsume($mem,$self->{opbits});

  # get argcount
  my $tab     = $self->{info};
  my $cnt     = $tab->{$id}->{cnt};

  # get arg types
  my ($mode)=bitsume($mem,$cnt);


  # ^walk args
  my @out=();

  while($cnt) {

    my $imm=$mode & 1;

    # immediate value
    if($imm) {
      my ($value)=rdimm($mem);
      push @out,$value;

    # memory operand
    } else {

      my ($slow)=bitsume($mem,1);

      # register or cache
      if(! $slow) {

        my ($addr)=bitsume(
          $mem,$Mach::Seg::FAST_BITS

        );

        push @out,Mach::Seg->fetch($addr);

      # regular segment
      } else {
        my ($loc,$addr)=rdmem($mem);
        push @out,Mach::Seg->fetch($loc,$addr);

      };

    };

    $mode >>= 1;
    $cnt--;

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

sub rdimm($mem,$cnt=1) {

  my (@width)=bitsume($mem,(2) x $cnt);
  map {$ARG=2**($ARG+3)} @width;

  my @value=bitsume($mem,@width);

  return @value;

};

# ---   *   ---   *   ---
# ^read width of memory operand
# then it's actual value

sub rdmem($mem) {

  my ($width)=bitsume($mem,3);
  $width=4+$width*4;

  my ($raw) = bitsume($mem,$width*2);
  my $mask  = bitmask($width);

  my $loc   = $raw & $mask;
  my $addr  = $raw >> $width;

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
  map {

    # pair [key  => base]
    # and  [base => info]
    $base->{$ARG->{key}} = $ARG->{id};
    $info->{$ARG->{id}} = {

      fn    => $ARG->{fn},
      cnt   => $ARG->{cnt},
      arg_t => $ARG->{arg_t},

    };

  } @{$frame->{-cstruc}};

  # make ice
  my $out=bless {

    base   => $base,
    info   => $info,

    opbits => $frame->{-opbits},
    opsize => $frame->{-opsize},
    opmask => $opmask,

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
# test

use Fmat;

# generate opcode table
my $f=Mach::Opcode->new_frame();
$f->engrave("Mach::Micro");

my $tab=$f->regen();

# ^store in memory
my $mem=Mach::Seg->new(0x20,fast=>1);
my $ptr=$mem->brush();

my $m1=Mach::Seg->new(0x10,fast=>1);
my $m2=Mach::Seg->new(0x10,fast=>1);

$m2->set(num=>0b1100);
$m1->set(num=>0b10);

$tab->write($ptr,'bshl',$m2,$m1);

# ^read
my @calls=$tab->read($mem);

# ^exec
map {

  my ($fn,@args)=@$ARG;
  $fn->(@args);

} @calls;

machxe(${$m2->{buf}},beg=>15,end=>16,line=>1);

# ---   *   ---   *   ---
1; # ret
