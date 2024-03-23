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

  use Arstd::Bytes;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,$ipret) {
  return bless {ipret=>$ipret},$class;

};

# ---   *   ---   *   ---
# get ref to ISA spec

sub ISA($self) {

  my $main = $self->{ipret};
  my $mc   = $main->{mc};

  return $mc->{ISA};

};

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

  } $self->ISA()->encoding($idex,$args);


  # give (opcode,bytesize)
  return ($opcd,int_urdiv($cnt,8));

};

# ---   *   ---   *   ---
# get opcode from descriptor

sub get_opcd($self,$type,$name,@args) {

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

sub array_get_opcd($self,$program) {

  map {

    my ($opcd,$size)=
      $self->get_opcd(@$ARG);

    (length $opcd)
      ? [$opcd,$size]
      : return null
      ;


  } @$program;

};

# ---   *   ---   *   ---
# crux

sub encode($self,$program) {


  # get ctx
  my $main = $self->{ipret};
  my $mc   = $main->{mc};
  my $mem  = $mc->{bk}->{mem};

  # fstate
  my $bytes = '';
  my $total = 0;


  # stirr [opcode,size] array
  map {

    my ($opcd,$size)=@$ARG;

    my $fmat = join ',',typeof $size;
    my $have = bpack $fmat,$opcd;

    $bytes .= $have->{ct};
    $total += $size;

  } array_get_opcd($program);


  # give (bytecode,size)
  return ($bytes,$total);

};

# ---   *   ---   *   ---
# read next argument from opcode

sub decode_args(

  $self,

  $opcdref,
  $flagsref,
  $csumeref,

  $load

) {


  # read elem flags and shift out bits
  my $flag        = $$flagsref & $ARGFLAG_BM;
     $$flagsref >>= $ARGFLAG_BS;


  # get binary format for arg
  my $fmat=undef;
  for my $key(@$ARGFLAG_BITS) {

    if($flag eq $ARGFLAG->{$key}) {
      $fmat=Bitformat $key;
      last;

    };

  };


  # read bits as hash
  my $mc   = $self->getmc();
  my %data = $fmat->from_value($$opcdref);

  $$opcdref  >>= $fmat->{bitsize};
  $$csumeref  += $fmat->{bitsize};


  # have memory operand?
  if(0 == index $fmat->{id},'m',0) {
    my $fn="decode_$fmat->{id}_ptr";
    $mc->$fn(\%data);


  # have register?
  } elsif($fmat->{id} eq 'r') {

    %data=(
      seg  => $mc->{anima}->{mem},
      addr => $data{reg} * $mc->{anima}->size(),

    );

  };


  return \%data;

};

# ---   *   ---   *   ---
# ^undo ;>

sub decode($self,$opcd) {


  # get ctx
  my $mask = $Cache->{id_bm};
  my $bits = $Cache->{id_bs};

  # count number of bits consumed
  my $csume = 0;


  # get opid and shift out bits
  my $opid    = $opcd & $mask;
     $opcd  >>= $bits;
     $csume  += $bits;

  # read instruction meta
  my $idex = ($opid << 1) + 1;
  my $ins  = $Cache->{romtab}->[$idex]->{ROM};


  # decode args
  my $cnt   = $ins->{argcnt};
  my $flags = $ins->{argflag};
  my @load  = ($ins->{load_dst},$ins->{load_src});

  my @args    = map {

    $self->decode_args(

      \$opcd,
      \$flags,
      \$csume,

      shift @load

    )

  } 0..$cnt-1;


  return {

    ins  => $ins,
    size => int_urdiv($csume,8),

    dst  => $args[0],
    src  => $args[1],

  };

};

# ---   *   ---   *   ---
1; # ret
