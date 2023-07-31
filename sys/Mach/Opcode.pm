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
  use List::Util qw(min);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::PM;

  use Mach::Seg;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#b
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

  Readonly our $ARG_BITS  => 3;
  Readonly our $ARG_MASK  => bitmask($ARG_BITS);
  Readonly our $FAST_MASK => 0b111;

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
#
# this first step provides only
# enough information to encode the
# *final* instruction

sub encode_base($class,$frame,$d) {

  return

    ($d->{id}  << (0))
  | ($d->{cnt} << ($frame->{-opbits}))

  | ($d->{stk} << ($frame->{-opbits}+$ARG_BITS))
  | ($d->{tab} << ($frame->{-opbits}+$ARG_BITS+1))

  ;

};

# ---   *   ---   *   ---
# ^expands base encoding, taking
# args into account

sub encode($self,$base,@args) {

  # unpack base
  my ($id,$cnt,$stk,$tab);

  $id     = $base & $self->{opmask};
  $base <<= $self->{opbits};

  $cnt    = $base & $ARG_MASK;
  $base <<= $ARG_BITS;

  $stk    = $base & 1;
  $tab    = $base & 2;


  # encode args
  my @pack = ();
  my $mode = 0x00;
  my $i    = 0;

  for my $arg(@args) {

# ---   *   ---   *   ---
# TODO
#
# "fast" memory should be capped to N
# bits wide, depending on how a Mach ice
# is set up; more caches and regs would
# mean a higher cap
#
# however, this requires that all subsystems
# are working and fully integrated into core,
# which is not (yet) the case!
#
# we'll have to hardcode this for now...

my $mask=$FAST_MASK;

# ---   *   ---   *   ---

    my $x=0x00;

    # register/memory operand
    if(Mach::Seg->is_valid($arg)) {

      my @bytes=lmord(

        $arg->{addr},

        width => 64,
        rev   => 0,

      );

      if($arg->{fast}) {
        $bytes[0] &= ($mask<<1);

      };

      push @pack,@bytes;

    # ^immediate
    } else {
      $mode |= 1<<$i;
      push @pack,$arg;

    };

    $i++;

  };

  map {say $ARG} @pack;

};

# ---   *   ---   *   ---
# ^bat-crux

sub regen($class,$frame) {

  my $keys  = {};
  my $xlate = {};

  # width of instruction bits
  $frame->{-opbits}=bitsize(
    $frame->{-opidex}

  );

  # ^width of opcode base
  $frame->{-opsize}=int_align(
    $frame->{-opbits},8

  );

  # run through loaded descriptors
  map {

    my $base=$frame->encode_base($ARG);

    # pair [fn   => base]
    # and  [base => coderef]
    $keys->{$ARG->{key}} = $base;
    $xlate->{$base}      = $ARG->{fn};

  } @{$frame->{-cstruc}};

  # make ice
  my $out=bless {

    keys   => $keys,
    xlate  => $xlate,

    opbits => $frame->{-opbits},
    opsize => $frame->{-opsize},
    opmask => bitmask($frame->{-opbits}),

  },$class;

  return $out;

};

# ---   *   ---   *   ---
# read instructions from segment

sub rdi($self,$ptr) {

  my @ins=map {
    $self->{xlate}->{$ARG}

  } $ptr->to_bytes($self->{opsize});

  $ptr->inc();

  return @ins;

};

# ---   *   ---   *   ---
# ^write to seg

sub ldi($self,$ptr,$ins,@args) {

  my ($opcode)=$self->{keys}->{$ins};

  $ptr->from_bytes(
    [$opcode],$self->{opsize}

  );

};

# ---   *   ---   *   ---
# test

use Fmat;
sub fn($a,$b) {};

my $f=Mach::Opcode->new_frame();
$f->add('fn');

my $mem=Mach::Seg->new(0x10,fast=>1);
my $tab=$f->regen();

fatdump(\$tab,blessed=>1);

$tab->encode(

  $tab->{keys}->{'fn'},
  $mem,1

);

# ---   *   ---   *   ---
1; # ret
