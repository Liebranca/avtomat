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

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    -autoload=>[qw(
      add regen

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

sub encode_base($d) {

  return

    ($d->{cnt} << 0)

  | ($d->{stk} << 3)
  | ($d->{tab} << 4)

  | ($d->{id}  << 5)

  ;

};

# ---   *   ---   *   ---

sub encode_args(

# ---   *   ---   *   ---
# ^bat-crux

sub regen($class,$frame) {

  my $keys  = {};
  my $xlate = {};

  # run through loaded descriptors
  map {

    my $opcode=encode_base($ARG);

    # pair [fn => opcode]
    # and  [opcode => coderef]
    $keys->{$ARG->{key}} = $opcode;
    $xlate->{$opcode}    = $ARG->{fn};

  } @{$frame->{-cstruc}};

  my $opbits = bitsize($frame->{-opidex});
  my $opsize = int_urdiv($opbits+5,8)*8;

  my $out    = bless {

    keys   => $keys,
    xlate  => $xlate,

    opbits => $opbits,
    opsize => $opsize,

    opmask => bitmask($opbits+5),
    frame  => $frame,

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
1; # ret
