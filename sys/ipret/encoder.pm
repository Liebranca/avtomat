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
1; # ret
