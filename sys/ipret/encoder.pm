#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET:ENCODER
# Program to bytes!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::encoder;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Type;
  use Bpack;
  use Bitformat;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::IO;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get instruction id from descriptor

sub insid($self,$type,$name,$args) {

  # get type from table
  $type=typefet $type
  or return null;

  # give valid instruction or null
  return $self->ISA()->get_ins_idex(

    $name,
    $type->{sizep2},

    map {$ARG->{type}}
    @$args

  );

};

# ---   *   ---   *   ---
# bytepack insid and operands

sub packins($self,$idex,$args) {

  # fstate
  my $opcd = 0x00;
  my $cnt  = 0;

  # walk and join [bitsize,bitpacked]
  map {

    my ($bs,$data)=@$ARG;

    $opcd |= $data << $cnt;
    $cnt  += $bs;

  } $self->ISA()->full_encoding($idex,$args);


  # give (opcode,bytesize)
  return ($opcd,int_urdiv($cnt,8));

};

# ---   *   ---   *   ---
# get opcode from descriptor

sub encode_opcd($self,$type,$name,@args) {

  # get instruction id
  my $idex=$self->insid(
    $type,$name,\@args

  );

  # ^give valid opcode or null
  return (length $idex)
    ? $self->packins($idex,\@args)
    : $idex
    ;

};

# ---   *   ---   *   ---
# ^bat

sub encode_program($self,$program) {

  map {

    my ($opcd,$size)=
      $self->encode_opcd(@$ARG);

    (length $opcd)
      ? [$opcd,$size]
      : return null
      ;


  } @$program;

};

# ---   *   ---   *   ---
# packs and pads encoded instruction

sub format_opcd($self,$ins) {

  return null if ! length $ins;

  my ($opcd,$size)=@$ins;

  my $have = join $NULLSTR,map {

    my $type  = typefet $ARG;
    my $bytes = pack $type->{packof},$opcd;

    $opcd >>= $type->{sizebs};
    $bytes;

  } typeof $size;


  return ($have,$size)

};

# ---   *   ---   *   ---
# descriptor array to bytecode

sub encode($self,$program) {


  # get ctx
  my $main = $self->{ipret};
  my $mc   = $main->{mc};
  my $mem  = $mc->{bk}->{mem};

  # fstate
  my $bytes = '';
  my $total = 0;
  my $end   = 0;


  # stirr [opcode,size] array
  map {

    my ($have,$size)=
      $self->format_opcd($ARG);

    $end    = $total;
    $bytes .= $have;
    $total += $size;


  } $self->encode_program($program);


  # align binary to ISA spec
  my $ISA     = $self->ISA;
  my $align_t = $ISA->align_t;

  # ^by null pad
  my $diff = $end % $align_t->{sizeof};

  $bytes .= pack "C[$diff]",(0) x $diff;
  $total += $diff;


  # give (bytecode,size)
  return ($bytes,$total);

};

# ---   *   ---   *   ---
# get binary format used to
# decode operand

sub operand_type($self,$operand) {


  # get ctx
  my $ISA   = $self->ISA;
  my $super = ref $ISA;

  my $enc_t = $ISA->enc_t;


  # get binary format for operand
  my $operand_t = $enc_t->operand_t($super);
  my ($type)    = grep {
    $operand eq $operand_t->{$ARG}

  } @{$enc_t->operand_types};

  my $fmat=Bitformat "$super.$type";


  return ($type,$fmat);

};

# ---   *   ---   *   ---
# read instruction bits
# from opcode

sub decode_instruction($self,$opcd) {


  # get ctx
  my $ISA  = $self->ISA;
  my $tab  = $ISA->opcode_table;

  my $mask = $tab->{id_bm};
  my $bits = $tab->{id_bs};


  # read instruction meta
  my $opid = $opcd & $mask;

  my $idex = ($opid << 1) + 1;
  my $ins  = $tab->{romtab}->[$idex]->{ROM};


  return ($ins,$bits);

};

# ---   *   ---   *   ---
# read next argument from opcode

sub decode_operand($self,$opcd,$operand) {


  # get type/packing fmat
  my ($type,$fmat)=
    $self->operand_type($operand);

  # read opcode bits into hash
  my $mc   = $self->{main}->{mc};
  my %data = $fmat->from_value($opcd);


  # have memory operand?
  if(0 == index $type,'m',0) {
    my $fn="decode_${type}_ptr";
    $mc->$fn(\%data);


  # have register?
  } elsif($type eq 'r') {

    %data=(
      seg  => $mc->{anima}->{mem},
      addr => $data{reg} * $mc->{anima}->size(),

    );

  };


  return (\%data,$fmat);

};

# ---   *   ---   *   ---
# ^bat

sub decode_operands($self,$ins,$opcd) {


  # read operand types from ROM
  my $cnt      = $ins->{argcnt};
  my $operands = $ins->{operands};
  my $size     = 0;


  # read operand data from opcode
  my $enc_t      = $self->ISA->enc_t;
  my ($dst,$src) = map {


    # get next
    my $operand    = $operands & $enc_t->operand_bm;
       $operands >>= $enc_t->operand_bs;

    # ^decode
    my ($out,$fmat)=
      $self->decode_operand($opcd,$operand);


    # go next and give
    $opcd >>= $fmat->{bitsize};
    $size  += $fmat->{bitsize};

    $out;


  } 0..$cnt-1;


  return ($dst,$src,$size);

};

# ---   *   ---   *   ---
# get descriptor from opcode

sub decode_opcode($self,$opcd) {


  # read instruction
  my ($ins,$ins_sz)=
    $self->decode_instruction($opcd);

  $opcd >>= $ins_sz;


  # read operands
  my ($dst,$src,$opr_sz)=
    $self->decode_operands($ins,$opcd);


  # give descriptor
  my $size=$ins_sz+$opr_sz;

  return {

    ins  => $ins,
    size => int_urdiv($size,8),

    dst  => $dst,
    src  => $src,

  };

};

# ---   *   ---   *   ---
# bytecode to descriptor array

sub decode($self,$program) {


  # get ctx
  my $ISA     = $self->ISA;
  my $align_t = $ISA->align_t;

  my $limit   = length $program;
  my $step    = $align_t->{sizeof};


  # consume buf
  my $ptr=0x00;
  my @out=();

  while($ptr+$step <= $limit) {


    # get next
    my $s    = substr $program,$ptr,$step;
    my $opcd = unpack $align_t->{packof},$s;

    # ^consume bytes and give
    my $ins  = $self->decode_opcode($opcd);
       $ptr += $ins->{size};

    push @out,$ins;

  };


  return \@out;

};

# ---   *   ---   *   ---
1; # ret
