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
  use List::Util qw(min max);

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

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    -autoload=>[qw(
      add encode_base regen

    )],

    -cstruc=>[],

    -opidex=>0,
    -opsize=>0,
    -opbits=>0,

  }};

  Readonly our $ARG_BITS  => 2;
  Readonly our $ARG_MASK  => bitmask($ARG_BITS);

# ---   *   ---   *   ---
# generate descriptor for instruction
#
# guts v

sub new($class,$frame,$name,%O) {

  state $re=qr{^(?:
    (?<stk> \@)
  | (?<tab> \%)

  )}x;

  # defaults
  $O{lis} //= $name;
  $O{pkg} //= caller;

  # instruction descriptor
  my $fn  = join q[::],$O{pkg},$name;
  my $out = {

    key => $O{lis},

    id  => $frame->{-opidex}++,
    fn  => \&$fn,

    stk => 0,
    tab => 0,
    cnt => 0,

  };

  # get signature
  my @sig=argsof($O{pkg},$name);
  my $end=$sig[-1];

  # get last argument is special
  if($end && $end=~ $re) {
    $out->{stk}=defined $+{stk};
    $out->{tab}=defined $+{tab};

    pop @sig;

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
# transform descriptor to numerical repr

sub encode($self,$key,@args) {

  my $id   = $self->{base}->{$key};
  my $info = $self->{info}->{$id};

  # ^unpack
  my $cnt = $info->{cnt};
  my $stk = $info->{stk};
  my $tab = $info->{tab};

  $cnt == int @args
  or throw_badargs($key,$cnt,int @args);

  # encode args
  my @pack = ();
  my $mode = 0x00;
  my $i    = 0;

  for my $arg(@args) {

    my $x=0x00;

    # register/memory operand
    if(Mach::Seg->is_valid($arg)) {
      push @pack,@{$arg->{addr}};

    # ^immediate
    } else {
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

    $cnt  => $ARG_BITS,
    $mode => $ARG_BITS,

  );

  return bitcat(@pack);

};

# ---   *   ---   *   ---
# ^reads back instruction from mem

sub decode($self,$sref) {

  my $br=0;

  # unpack base
  my ($id,$cnt,$mode)=bitsume(

    $sref,

    $self->{opbits},
    ($ARG_BITS) x 2

  );

  $br+=
    $self->{opbits}
  + ($ARG_BITS * 2)
  ;


  # ^walk args
  my @out=();

  while($cnt) {

    my $imm=$mode & 1;

    # immediate value
    if($imm) {

      my ($width)=bitsume($sref,2);
      $width=2**($width+3);

      my ($value)=bitsume($sref,$width);

      $br+=2+$width;

      push @out,$value;

    # memory operand
    } else {

      my ($slow)=bitsume($sref,1);
      $br++;

      # register or cache
      if(! $slow) {

        my ($addr)=bitsume(
          $sref,$Mach::Seg::FAST_BITS

        );

        $br+=$Mach::Seg::FAST_BITS;

        push @out,Mach::Seg->ffetch($addr);

      # regular segment
      } else {
        nyi('SLOW SEG');

      };

    };

    $mode >>= 1;
    $cnt--;

  };


  # consume byte leftovers
  my $diff=int_align($br,8);
     $diff=$diff - $br;

  bitsume($sref,$diff) if $diff;
  $br+=$diff;


  # give bits read + decoded instruction
  unshift @out,$self->{info}->{$id}->{fn};
  return @out;

};

# ---   *   ---   *   ---
# ^errme

sub throw_badargs($key,$cnt,$have) {

  errout(

    q[BADARGS: %u/%u args for '%s'],

    lvl  => $AR_FATAL,
    args => [$have,$cnt,$key],

  );

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

      fn  => $ARG->{fn},

      cnt => $ARG->{cnt},
      stk => $ARG->{stk},
      tab => $ARG->{tab},

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

sub load($self,$ptr) {

  my @out = ();
  my $mem = ${$ptr->{buf}};

  # first byte is set means
  # instruction in Q
  while(ord substr $mem,0) {
    push @out,[$self->decode(\$mem)];

  };

  return @out;

};

# ---   *   ---   *   ---
# ^write to seg

sub store($self,$ptr,$ins,@args) {

  my ($opcode,$width)=$self->encode($ins,@args);

  $width=int_urdiv($width,8);

  $ptr->set(rstr=>$opcode);
  $ptr->brush($width,repl=>1);

};

# ---   *   ---   *   ---
# test

use Fmat;
sub fn($a,$b) {say "$a,$b"};

# generate opcode table
my $f=Mach::Opcode->new_frame();
$f->add('fn');

my $tab=$f->regen();


# ^store in memory
my $mem=Mach::Seg->new(0x20,fast=>1);
my $ptr=$mem->brush();

$tab->store($ptr,'fn',1,2);
$tab->store($ptr,'fn',2,1);

# ^read
my @calls=$tab->load($mem);

# ^exec
map {

  my ($fn,@args)=@$ARG;
  $fn->(@args);

} @calls;

# ---   *   ---   *   ---

$mem->prich();

# ---   *   ---   *   ---
1; # ret
