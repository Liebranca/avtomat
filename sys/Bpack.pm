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

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(bpack bunpack);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# pack using peso type

sub bpack($type,@data) {

  # fetch if need
  $type=typefet $type;


  # make bytearray and give
  my $bytes=(
    pack $type->{packof} x int @data,
    map  {unlay($type,$ARG)} @data

  );

  return ($bytes,length $bytes);

};

# ---   *   ---   *   ---
# ^unpack

sub bunpack($type,$src,$pos=0) {

  # fetch if need
  $type=typefet $type;


  # read from buf
  my $bytes = substr $src,$pos,$type->{sizeof};

  # ^make num from bytes
  my $fmat  = $type->{packof};
  my @out   = unpack $fmat,$bytes;


  # ^copy layout and give
  return layas($type,@out);

};

# ---   *   ---   *   ---
# copy layout of type

sub layas($type,@src) {

  # copy type layout
  my @out=map {

    ($ARG > 1)
      ? [map {shift @src} 1..$ARG]
      : shift @src
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
# ^undo

sub unlay($type,$src) {

  # de-hashing on structures
  if(is_hashref($src)) {

    my $field = $type->{struc_i};
       $src   = [map {$src->{$ARG}} @$field];

  # ^noop on plain value
  } elsif(! is_arrayref($src)) {
    $src=[$src];

  };


  # give plain value list
  return array_flatten($src);

};

# ---   *   ---   *   ---
1; # ret
