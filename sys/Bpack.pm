#!/usr/bin/perl
# ---   *   ---   *   ---
# BPACK
# Bytepacker
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Bpack;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use Arstd::Array;
  use Arstd::IO;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(bpack bunpack bunpacksu);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.6;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# strucs can be passed in
# three different ways:
#
# * single hashref
#   eg typefet $name
#
# * hashref arrayref
#   eg [map {typefet $ARG} @names]
#
# * comma-separated string,
#   eg join ',',@names
#
#
# this F handles unpacking them all!

sub strucun($src) {

  # first two cases
  return $src  if is_hashref  $src;
  return @$src if is_arrayref $src;

  # ^else we have a string
  map   {typefet $ARG}
  split $COMMA_RE,$src;

};

# ---   *   ---   *   ---
# ~

sub deforz {(defined $_[0]) ? $_[0] : 0x00 };

# ---   *   ---   *   ---
# de-nesting of peso type

sub unlay($type,$src) {

  # de-hashing on structures
  if(is_hashref($src)) {

    my $field = $type->{struc_i};
       $src   = [map {deforz $src->{$ARG}} @$field];

  # ^effectively noop on plain value
  } elsif(! is_arrayref($src)) {
    $src=[$src];

  };


  # give plain value list
  return array_flatten($src);

};

# ---   *   ---   *   ---
# pack using peso types

sub bpack($struc,@data) {

  # fetch
  my @type=strucun($struc);


  # ^match data to type
  my $idex  = 0;
  my $len   = 0;

  my @bytes = map {


      # get next type
      my $type = array_wrap(\@type,$idex++);
      my $size = $type->{sizeof};
      my $fmat = $type->{packof};

      # have string?
      my ($str_t) = Type->is_str($type);
      my $cnt     = ($str_t)
        ? int($fmat ne 'ux')+length $ARG
        : 1
        ;

      if($str_t && $fmat eq 'ux') {

        my $give=pack 'ux',unlay $type,$ARG;
        $len += length $give;

        $give;

      } else {

        $len += $size * $cnt;


        # ^pack chunk accto type
        pack  $type->{packof},
        unlay $type,$ARG;

      };


  } array_flatten [@data];


  # give content/length
  return {
    ct  => (catar @bytes),
    len => $len

  };

};

# ---   *   ---   *   ---
# copy layout of peso type

sub layas($type,@src) {

  # copy type layout
  my @out=map {

    ($ARG > 1)
      ? [map {deforz shift @src} 1..$ARG]
      : deforz shift @src
      ;


  } @{$type->{layout}};


  # make struc?
  @out=(@{$type->{struc_t}})
    ? _layas_struc($type,@out)
    : @out
    ;

  # give list if need
  return (@out == 1) ? $out[0] : \@out ;

};

# ---   *   ---   *   ---
# ^makes hashref!

sub _layas_struc($type,@src) {

  # [idex => name]
  my $fi    = 0;
  my $field = $type->{struc_i};

  # from X->[idex]
  # to   X->{name}
  return {map {$ARG=>$src[$fi++]} @$field};

};

# ---   *   ---   *   ---
# unpack using peso types

sub bunpack($struc,$srcref,$pos=0,$cnt=1) {


  # force source to be a reference ;>
  $srcref=\$srcref
  if ! length ref $srcref;


  # fetch structure!
  my @type=strucun($struc);


  # ^match data to type
  my $len    = 0;
  my @values = map {


    # get next chunk
    my $type = array_wrap(\@type,$ARG);
    my $fmat = $type->{packof};
    my $size = $type->{sizeof};

    # check for overflow
    my $stop=(length $$srcref)-$pos;
    return null if $stop < 0;


    # read buffer
    my $src  = substr $$srcref,$pos,$stop;
    my @have = unpack $fmat,$src;

    # have string?
    my ($str_t) = Type->is_str($type);
    my $cnt     = ($str_t)
      ? int($fmat ne 'ux')+length $have[0]
      : 1
      ;

    if($str_t && $fmat eq 'ux') {
      $cnt  = length pack 'ux',$have[0];
      $size = 1;

    };

    $pos += $size * $cnt;
    $len += $size * $cnt;


    # copy type layout
    layas $type,@have;


  } 0..$cnt-1;


  # give content/length
  return {
    ct  => \@values,
    len => $len

  };

};

# ---   *   ---   *   ---
# ^consumes input

sub bunpacksu($struc,$srcref,$pos=0,$cnt=1) {

  my $cpy=$$srcref;
  my $b=bunpack($struc,$srcref,$pos,$cnt);

  errout "cannot unpack struc '%s'",

  args => [

    (is_hashref $struc)
      ? $struc->{name}
      : $struc
      ,

  ],

  lvl  => $AR_FATAL,

  if ! length $b;

  substr $$srcref,$pos,$b->{len},$NULLSTR;

  return $b;

};

# ---   *   ---   *   ---
1; # ret
