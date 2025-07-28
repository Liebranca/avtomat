#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ISA:ENCODING
# How we shuffle exebits
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package A9M::ISA::encoding;
  use v5.42.0;
  use strict;
  use warnings;

  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;
  use Type;
  use Warnme;

  use Bitformat;
  use FF;

  use Arstd::Bytes;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.3a';
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # operand data
  operand_bs => 3,
  operand_bm => sub {
    bitmask $_[0]->operand_bs;

  },

  argnames => [
    [],['dst'],['dst','src'],

  ],

  operand_types=>[qw(

    r

    mstk mimm msum mlea
    ix   iy   iz

  )],


  # bitsizes for types of immediates
  ix_bs         => 8,
  iy_bs         => 16,
  iz_bs         => 32,

  mlea_scale_bs => 2,


};

# ---   *   ---   *   ---
# ^further encodings that
# require instance data!

sub generate($class,$ISA) {


  # get ctx
  my $mc       = $ISA->getmc();
  my $anima    = $mc->{bk}->{anima};
  my $super    = ref $ISA;


  # operand encoding
  my $operand_t=$class->operand_t($super);

  %$operand_t=(


    # base format
    %{Bitformat "$super.operand"=>(
      dst => $class->operand_bs,
      src => $class->operand_bs,

    )},


    # ^possible values
    r    => 0b000,

    mstk => 0b001,
    mimm => 0b010,
    msum => 0b011,
    mlea => 0b100,

    ix   => 0b101,
    iy   => 0b110,
    iz   => 0b111,

  );


  # ^shifted to src bit
  map {

    $operand_t->{"src_$ARG"}=
       $operand_t->{$ARG}
    << $operand_t->{pos}->{src};

  } @{$class->operand_types};


  # instruction meta
  Bitformat "$super.opcode"=>(

    load_src    => 1,
    load_dst    => 1,
    overwrite   => 1,

    argcnt      => 2,
    operands    => $operand_t->{bitsize},

    opsize      => 2,
    idx         => 16,

  );

  # enconding for register operands
  Bitformat "$super.r"=>(
    reg => $anima->cnt_bs,

  );


  # encodings for immediate operands
  Bitformat "$super.ix"=>(
    imm => $class->ix_bs,

  );

  Bitformat "$super.iy"=>(
    imm => $class->iy_bs,

  );

  Bitformat "$super.iz"=>(
    imm => $class->iz_bs,

  );


  # encodings for memory operands
  Bitformat "$super.mstk"=>(
    imm => $class->ix_bs,

  );

  # [imm]
  Bitformat "$super.mimm"=>(
    imm => $class->iy_bs,

  );

  # [r+imm]
  Bitformat "$super.msum"=>(
    reg => $anima->cnt_bs,
    imm => $class->ix_bs,

  );

  # [r+r+imm*s]
  Bitformat "$super.mlea"=>(

    rX    => $anima->cnt_bs,
    rY    => $anima->cnt_bs,

    imm   => $class->mlea_scale_bs+$class->ix_bs,
    scale => $class->mlea_scale_bs,

  );


  return;

};

# ---   *   ---   *   ---
# build these last as we first
# need to know how big opcodes are!

sub postgen($class,$super) {


  # get ctx
  my $tab=$super->opcode_table;


  # get opcode/mnemonic counts
  my @sizes = (

    $tab->{id_bs},
    bitsize($tab->{id_bm}),

    $tab->{idx_bs},
    bitsize($tab->{idx_bm}),

  );


  # ^map to types
  my (

    $id_bs_t,
    $id_bm_t,

    $idx_bs_t,
    $idx_bm_t,

  )=map {

    Type::bitfit($ARG)

  } @sizes;

  # fmat for binary section
  # of resulting ROM
  FF "$super.opcode-tab"=>

    "$id_bm_t->{name}  id_mask;"
  . "$idx_bm_t->{name} idx_mask;"

  . "$id_bm_t->{name} id_bits;"
  . "$idx_bm_t->{name} idx_bits;"

  . "bit<$super.opcode> opcode[word];";


  return;

};

# ---   *   ---   *   ---
# fetches operand encoding

sub operand_encoding($class,$super,$name) {
  return Bitformat "$super.$name";

};

sub operand_t($class,$super,$name=undef) {

  my $tab=$class->classcache(
    "$super.operand_t"

  );

  return (defined $name)
    ? $tab->{$name}
    : $tab
    ;

};

# ---   *   ---   *   ---
# build table to match name
# to operand type

sub operand_tid($class,$super) {


  my $operand_t=$class->operand_t($super);


  return {

    q[]      => 0b000000,
    d        => 0b000000,
    s        => 0b000000,


    dr       => $operand_t->{r},

    dmstk    => $operand_t->{mstk},
    dmimm    => $operand_t->{mimm},
    dmsum    => $operand_t->{msum},
    dmlea    => $operand_t->{mlea},

    dix      => $operand_t->{ix},
    diy      => $operand_t->{iy},
    diz      => $operand_t->{iz},


    sr       => $operand_t->{src_r},

    smstk    => $operand_t->{src_mstk},
    smimm    => $operand_t->{src_mimm},
    smsum    => $operand_t->{src_msum},
    smlea    => $operand_t->{src_mlea},

    six      => $operand_t->{src_ix},
    siy      => $operand_t->{src_iy},
    siz      => $operand_t->{src_iz},

  };

};

# ---   *   ---   *   ---
1; # ret
