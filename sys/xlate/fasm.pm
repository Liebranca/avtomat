#!/usr/bin/perl
# ---   *   ---   *   ---
# XLATE FASM
# Virtual to native!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package xlate::fasm;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use St;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  metains  => qr{^(?:

    load_chan

  )$}x,

  instab => {

    ld    => 'mov',
    lz    => 'cmovz',

    _cmp  => 'cmp',

  },

  register => sub {

    my $class=$_[0];

    return {

      0x0 => $class->rX('a'),
      0x1 => $class->rX('12'),
      0x2 => $class->rX('c'),
      0x3 => $class->rX('13'),
      0x4 => $class->rX('di'),
      0x5 => $class->rX('si'),
      0x6 => $class->rX('d'),
      0x7 => $class->rX('10'),

      0x8 => $class->rX('8'),
      0x9 => $class->rX('9'),

      0xA => $class->rX('sp'),
      0xB => $class->rX('bp'),

      0xC => $class->rX('b'),
      0xD => $class->rX('15'),

      0xE => $class->rX('14'),
      0xF => $class->rX('11'),

    };

  },

};

# ---   *   ---   *   ---
# A9M registers to x86

sub rX($class,$name) {


  # name in [rax,rbx,rcx,rdx] ?
  if($name=~ qr{^(?:a|b|c|d)$}) {

    return {

      qword => "r${name}x",
      dword => "e${name}x",
      word  => "${name}x",
      byte  => "${name}l",

    };


  # name in [rdi,rsi,rsp,rbp] ?
  } elsif($name=~ qr{^(?:di|si|sp|bp)$}) {

    return {

      qword => "r${name}",
      dword => "e${name}",
      word  => "${name}",
      byte  => "${name}l",

    };


  # name in [r8-15] !
  } else {

    return {

      qword => "r${name}",
      dword => "r${name}d",
      word  => "r${name}w",
      byte  => "r${name}b",

    };

  };

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$main) {
  return bless {main=>$main},$class;

};

# ---   *   ---   *   ---
# ~

sub ptr_decode($self,$type,$x) {

  my $main  = $self->{main};
  my $l1    = $main->{l1};

  my $have  = $l1->xlate($x);


  if($have->{type} eq 'REG') {
    my $value=$self->register->{$have->{spec}};
    return $value->{qword};

  } else {
    return $have->{spec};

  };

};

# ---   *   ---   *   ---
# get value from descriptor

sub operand_value($self,$ins,$type,$data) {

  map {

    my $e     = {%{$data->{$ARG}}};
    my $value = $e->{value};

    if(is_arrayref $value) {

      my $scale = shift @$value;
      my @have  = map {
        $self->ptr_decode($type,$ARG)

      } @$value;


      my $ptr  = join null,map {

        my $v=$have[$ARG];

        if($ARG >= 1 && 0 > index $v,'-') {
          "+$v";

        } else {$v};

      } 0..$#have;

      $value=($scale > 1)
        ? "$ptr*$scale"
        : "$ptr"
        ;

      $value="$type->{name} [$value]";


    } elsif($e->{type} eq 'r') {
      $value=$self->register->{$value};
      $value=$value->{$type->{name}};

    };


    "$value"


  } qw(dst src)[0..$ins->{argcnt}-1];

};

# ---   *   ---   *   ---
# ~

sub step($self,$data) {


  # get ctx
  my $ISA  = $self->{main}->{mc}->{ISA};
  my $guts = $ISA->{guts};
  my $tab  = $ISA->opcode_table;

  my $ins  = $data->{ins};

  # get function assoc with id
  # skip meta instructions!
  my $fn=$tab->{exetab}->[$ins->{idx}];
  return () if $fn=~ $self->metains;

  # need to translate?
  my $xtab=$self->instab;

  $fn=$xtab->{$fn}
  if exists $xtab->{$fn};


  # read operands
  my $ezy    = Type::MAKE->LIST->{ezy};
  my $type   = typefet $ezy->[$ins->{opsize}];

  my @values =$self->operand_value(
    $ins,$type,$data

  );


  say sprintf
    "%-8s  " . join(',',@values),$fn;

  return ();

};

# ---   *   ---   *   ---
1; # ret
