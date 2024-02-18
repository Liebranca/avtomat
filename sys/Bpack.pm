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
  use Type;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(bpack bunpack);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# pack/unpack using peso types

sub _bpack_proto($f,$ezy,@data) {

  my @out   = ([]);
  my $total = 0;

  my @types = split $COMMA_RE,$ezy;


  # make sub ref
  $f = "_array$f";
  $f = \&$f;

  # ^call
  (@out)=$f->(
    \@types,@data

  );

  $total=pop @out;


  return (@out,$total);

};

# ---   *   ---   *   ---
# ^bat
#
# it *is* terrible
#
# however, this spares us having
# to duplicate two almost identical
# subroutines

sub _array_bpack_proto(

  $f,

  $types,
  $data,

  $iref,
  $tref,
  $oref

) {

  # get format chars
  my $fmat=packof($types->[$$iref]);

  # ^call F with format,data
  push @{$oref->[0]},$f->($fmat,$data);
  $oref->[$$iref+1]++;

  $$tref+=(Type->is_valid($types->[$$iref]))
    ? sizeof($types->[$$iref])
    : 1+length $oref->[0]->[-1]
    ;


  # go next, wrap-around types
  $$iref++;
  $$iref&=$$iref * ($$iref < @$types);

};

# ---   *   ---   *   ---
# ^packing guts

sub _bpack($fmat,@data) {
  ($fmat,@data)=_fmat_data_break(1,$fmat,@data);
  return pack $fmat,@data;

};

# ---   *   ---   *   ---
# ^bat

sub _array_bpack($types,@data) {

  my @out   = ([],map {0} 0..@$types-1);

  my $idex  = 0;
  my $total = 0;

  # get type of each elem,
  # then pack individual elems
  map { _array_bpack_proto(

    \&_bpack,

    $types,
    $ARG,

    \$idex,
    \$total,
    \@out,

  )} @data;


  return (@out,$total);

};

# ---   *   ---   *   ---
# plain iface wraps

sub bpack($ezy,@data) {
  return _bpack_proto('_bpack',$ezy,@data);

};

# ---   *   ---   *   ---
# unpacking guts

sub _bunpack($fmat,$buf) {
  ($fmat,$buf)=_fmat_data_break(0,$fmat,$buf);
  return unpack $fmat,$buf;

};

# ---   *   ---   *   ---
# ^bat

sub _array_bunpack($types,$buf,$cnt) {

  my @out   = ([],map {0} 0..@$types-1);

  my $idex  = 0;
  my $total = 0;

  # get type of each elem,
  # then pack individual elems
  map { _array_bpack_proto(

    \&_bunpack,

    $types,
    (substr $buf,$total,(length $buf)-$total),

    \$idex,
    \$total,
    \@out,

  )} 0..($cnt*int @$types)-1;


  return (@out,$total);

};

# ---   *   ---   *   ---
# ^iface wraps
# unpacks and consumes bpack'd

sub bunpack($ezy,$sref,$cnt) {

  my ($ct,@cnt)=_bpack_proto(
    '_bunpack',$ezy,$$sref,$cnt

  );

  my $total=$cnt[-1];
  substr $$sref,0,$total,$NULLSTR;


  return ($ct,@cnt);

};

# ---   *   ---   *   ---
# handle perl string to cstring
# and other edge-cases, maybe...

Readonly my $PLCSTR_RE=>qr{\@Z};

sub _fmat_data_break($packing,$fmat,@data) {

  if($fmat=~ $PLCSTR_RE) {

    @data=map {(

      (map {ord($ARG)} split $NULLSTR,$ARG),
      0x00

    )} @data if $packing;

    $fmat=($packing) ? 'C*' : 'Z*';

  };

  return $fmat,@data;

};

# ---   *   ---   *   ---
1; # ret
