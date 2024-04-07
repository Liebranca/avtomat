#!/usr/bin/perl
# ---   *   ---   *   ---
# BITFORMAT
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

package Bitformat;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_words);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Bpack;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Int;

  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(Bitformat);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub Bitformat($name,@order) {

  my $id   = $name;
     $name = "bit<$name>";


  # ever lookup something
  # then realize you're holding it?
  return $name
  if Bitformat->is_valid($name);

  # fetch existing?
  return (exists $Type::MAKE::Table->{$name})
    ? $Type::MAKE::Table->{$name}
    : badtype $name

  if ! @order;


  # forbid redefinition
  return Type::warn_redef($name)
  if exists $Type::MAKE::Table->{$name};


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

    id => $id,

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


  },'Bitformat';


  $Type::MAKE::Table->{$name} = $self;
  return $self;

};

# ---   *   ---   *   ---
# ^ors values accto their
# position in format

sub bor($self,%data) {

  # need list output?
  return $self->array_bor(%data)
  if $self->{bytesize} > 8;


  # ^nope, single elem will do
  my $out=0x00;

  map {

    $data{$ARG} //= 0;
    $out         |=(

      $data{$ARG}
    & $self->{mask}->{$ARG}

    ) << $self->{pos}->{$ARG};

  } grep {
    defined array_iof($self->{order},$ARG)

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
# reads num into hash

sub from_value($self,$x) {

  map {

    my $key   = $ARG;
    my $value = $x & $self->{mask}->{$key};

    $x   >>=  $self->{size}->{$key};
    $key   => $value;


  } @{$self->{order}};

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
  return bpack byte=>@bytes;

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
  my @types = typeof($len);


  my $fmat  = join $NULLSTR,map {
    packof($ARG)

  } @types;


  my @data=unpack "$fmat" x $cnt,$raw;


  # ^read chunks into new struc(s)
  my $have   = 0;
  my $idex   = 0;
  my @chunks = ();

  my $out=[ map {

    my $out_elem={ map {


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

    } @{$self->{order}} };

    $have   = 0;
    $idex   = 0;
    @chunks = ();

    $out_elem;

  } 0..$cnt-1];


  return {ct=>$out,len=>$len*$cnt};

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
