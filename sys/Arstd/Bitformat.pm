#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD BITFORMAT
# So I don't have to
# MASH bits by hand
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::Bitformat;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_words);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Int;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,@order) {

  # out attrs
  my $size = {};

  my $mask = {'$:top;>'=>0};
  my $pos  = {'$:top;>'=>0};


  # array as hash
  my $idex   = 0;
  my @keys   = array_keys(\@order);
  my @values = array_values(\@order);

  # ^walk
  map {

    my $bits = $values[$idex++];

    $size->{$ARG}      = $bits;

    $pos->{$ARG}       = $pos->{'$:top;>'};
    $mask->{$ARG}      = (1 << $bits)-1;

    $pos->{'$:top;>'} += $bits;

  } @keys;

  # calc mask for total size
  $mask->{'$:top;>'}=
    (1 << $pos->{'$:top;>'})-1;


  # make ice
  my $self=bless {

    size  => $size,
    mask  => $mask,

    pos   => $pos,
    order => \@keys,

  };


  return $self;

};

# ---   *   ---   *   ---
# ^ors values accto their
# position in format

sub bor($self,%data) {

  my $out=0x00;

  map {$out |=(

    $data{$ARG}
  & $self->{mask}->{$ARG}

  ) << $self->{pos}->{$ARG}

  } keys %data;


  return $out;

};

# ---   *   ---   *   ---
# ^for strucs larger than 64 bits

sub array_bor($self,%data) {

  my @out=map {0} 0..$self->bytesize() >> 3;

  map {

    my $idex=int_urdiv(
      $self->{pos}->{$ARG},8

    ) >> 3;

    $out[$idex] |=(

      $data{$ARG}
    & $self->{mask}->{$ARG}

    ) << ($self->{pos}->{$ARG} & 0x3F);

  } keys %data;


  return @out;

};

# ---   *   ---   *   ---
# get bytesize of format

sub bytesize($self) {

  return int_urdiv(
    $self->{pos}->{'$:top;>'},8

  );

};

# ---   *   ---   *   ---
# (b)packs struc

sub to_bytes($self,%data) {

  my $len  = $self->bytesize();
  my @data = map {

    my $word=$ARG;
    map {($word >> ($ARG << 3)) & 0xFF} 0..7;

  } $self->array_bor(%data);

  @data=@data[0..$len-1];

  my ($ct,@cnt)=bpack(byte=>@data);
  $ct=join $NULLSTR,@$ct;

  return ($len,$ct);

};

# ---   *   ---   *   ---
# ^inserts result in buff

sub write($self,$sref,$pos,%data) {
  my ($len,$ct)=$self->to_bytes(%data);
  substr $$sref,$pos,$len,$ct;

  return $len;

};

# ---   *   ---   *   ---
# consume previously packed
# bytes into new struc

sub from_bytes($self,$sref,$pos) {

  # get bytearray at pos
  my $len=$self->bytesize();
  my $raw=substr $$sref,$pos,$len,$NULLSTR;

  # ^break down into chunks
  my @types = array_typeof($len);
  my $fmat  = join $NULLSTR,map {
    packof($ARG)

  } @types;

  my @data=unpack $fmat,$raw;


  # ^read chunks into new struc
  my $have   = 0;
  my @chunks = ();

  my %out=map {


    # get required size
    my $need = $self->{size}->{$ARG};
    my $mask = bitmask($need);

    while($have < $need) {

      my $ezy=sizeof(shift @types);

      push @chunks,$ezy,(shift @data);
      $have += $ezy << 3;

    };


    # consume chunks as needed
    my $pos   = 0;
    my $value = 0;

    while($need) {

      my $ezy   = shift @chunks;
      my $bytes = shift @chunks;

      $value |= ($bytes & $mask) << $pos;

      # partially consumed
      # give back remain
      if(($ezy << 3) > $need) {

        $have   -= $need;
        $ezy    -= $need >> 3;

        $bytes >>= $need;
        $need    = 0;

        unshift @chunks,$ezy,$bytes;

      # ^wholly consumed
      } else {
        $need -= $ezy << 3;
        $have -= $ezy << 3;

        $pos  += $ezy << 3;

      };

    };


    $ARG=>$value;

  } @{$self->{order}};


  return $len,%out;

};

# ---   *   ---   *   ---
1; # ret
