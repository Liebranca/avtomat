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

  our $VERSION = v0.00.6;#b
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

    # save total sizeof
    bytesize  => int_urdiv(
      $pos->{'$:top;>'},8

    ),

    bitsize => $pos->{'$:top;>'},


    # ^attrs
    size  => $size,
    mask  => $mask,
    pos   => $pos,


    # used for walking
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

  my @out=map {0} 0..$self->{bytesize} >> 3;

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
# (b)packs struc to bytestr

sub to_bytes($self,@data) {

  # elem size / elem count
  my $ezy = $self->{bytesize};
  my $cnt = int @data;

  # ^total
  my $cap = $ezy*$cnt;


  # get strucs as bytearrays
  #
  # final size if each element gets
  # padded to a multiple of eight bits!
  my @bytes = map { map {

    # split 64-bit elem into 8-bit
    my $word = $ARG;
    my @out  = map {
      ($word >> ($ARG << 3)) & 0xFF

    } 0..7;

    # ^discard padding bytes
    @out[0..$ezy-1]

  # get each bit struc as an array,
  # 64-bits per elem
  } $self->array_bor(%$ARG) } @data;


  # ^discard padding bytes (again!)
  @bytes=@bytes[0..$cap-1];

  # ^give peso-bytepack'd ;>
  my ($ct,@cnt)=bpack(byte=>@bytes);
  $ct=join $NULLSTR,@$ct;


  return ($ct,$cap);

};

# ---   *   ---   *   ---
# ^inserts result in existing
# bytestr

sub to_strm($self,$sref,$pos,@data) {

  my ($ct,$len)=$self->to_bytes(@data);
  substr $$sref,$pos,$len,$ct;

  return $len;

};

# ---   *   ---   *   ---
# read bytestr into new struc

sub from_bytes($self,$raw,$cnt=1) {

  # break down into chunks
  my $len   = $self->{bytesize};
  my @types = array_typeof($len);

  my $fmat  = join $NULLSTR,map {
    packof($ARG)

  } @types;

  my @data=unpack "$fmat\[$cnt]",$raw;


  # ^read chunks into new struc(s)
  my $have   = 0;
  my $idex   = 0;
  my @chunks = ();

  my $out=[ map {{ map {


    # get required size
    my $need = $self->{size}->{$ARG};
    my $mask = bitmask($need);

    while($have < $need) {

      my $ezy=sizeof($types[$idex++]) << 3;

      push @chunks,$ezy,(shift @data);
      $have += $ezy;

    };


    # consume chunks as needed
    my $pos   = 0;
    my $value = 0;

    while($need) {

      # get next
      my $ezy   = shift @chunks;
      my $bytes = shift @chunks;

      $value |= ($bytes & $mask) << $pos;


      # ^partially consumed
      # give back leftovers
      if(($ezy) > $need) {

        $have   -= $need;
        $ezy    -= $need;

        $bytes >>= $need;
        $need    = 0;

        unshift @chunks,$ezy,$bytes;


        # backtrack type
        $idex=($idex > 0)
          ? $idex-1
          : $#types
          ;


      # ^wholly consumed
      # nothing saved for next
      } else {
        $need -= $ezy;
        $have -= $ezy;

        $pos  += $ezy;

      };

    };

    # wrap type, go next and give
    $idex &= $idex * ($idex < @types);
    $ARG  => $value;

  } @{$self->{order}} }} 0..$cnt-1];


  return $out,$len*$cnt;

};

# ---   *   ---   *   ---
# ^consumes bytes

sub from_strm($self,$sref,$pos,$cnt=1) {

  my $len=$self->{bytesize};
  my $raw=substr $$sref,$pos,$len*$cnt,$NULLSTR;

  return $self->from_bytes($raw,$cnt);

};

# ---   *   ---   *   ---
1; # ret
