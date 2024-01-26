#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD STRUC
# An array of layouts
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::Struc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_words);

  use List::Util qw(sum);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Chk;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::Bitformat;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,@order) {

  # static patterns
  state $head_re   = qr{\s*\*\s*\[(.+)\]};
  state $rehead_re = qr{^\^};


  # array as hash
  my $idex   = 0;
  my @keys   = array_keys(\@order);
  my @values = array_values(\@order);

  # build header
  my @head_keys = ();
  my @head_fmat = ();
  my $rehead    = {};

  # header read/reuse filter
  state $rehead_chk = sub ($cntsz,$idex) {

    if($cntsz=~ s[$rehead_re][]) {
      $rehead->{$keys[$idex]}=$cntsz;

    } else {
      push @head_keys,$keys[$idex];
      push @head_fmat,$cntsz;

    };

  };


  # apply filter to struc format
  @values=map {

    # value is [Arstd::Bitformat,cntsize]
    if(is_arrayref($ARG)) {

      my ($fmat,$cntsz)=@$ARG;

      $rehead_chk->($cntsz,$idex)
      if defined $cntsz;

      $ARG=$fmat;

    # value is "fmat * [cntsize]"
    } elsif($ARG=~ s[$head_re][]) {
      $rehead_chk->($1,$idex);

    };

    # go next and give
    $idex++;
    $ARG;

  } @values;


  # ^have any header data?
  if(@head_fmat) {
    my $fmat=join ',',@head_fmat;
    unshift @head_keys,$fmat;

  };


  # get value=>fptr
  my @procs=map {

    (Arstd::Bitformat->is_valid($ARG))
      ? 1
      : 0
      ;

  } @values;


  # get sizeof (minus strings!)
  my $basesize=sum(map {

    if(Arstd::Bitformat->is_valid($ARG)) {
      $ARG->{bytesize};

    } else {
      sizeof($ARG);

    };

  } @values);


  # make ice
  my $self=bless {

    # save total sizeof
    basesize => $basesize,

    #   size fields to read
    # / size fields to reuse
    head    => \@head_keys,
    rehead  => $rehead,

    # the actual fields
    order   => \@keys,
    fmat    => \@values,
    proc    => \@procs,

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# proto: run F with elem

sub _proc_elem(

  $self,
  $on_struc,$on_prims,

  $e,$idex

) {

  # get ctx vars
  $e->{key}  = $self->{order}->[$idex];
  $e->{fmat} = $self->{fmat}->[$idex];

  # ^exec
  return ($self->{proc}->[$idex])
    ? $self->$on_struc($e)
    : $self->$on_prims($e)
    ;

};

# ---   *   ---   *   ---
# read from buff

sub from_bytes($self,$sref,$pos) {

  # bind ctx
  my $e={

    key  => $NULLSTR,
    fmat => $NULLSTR,

    src  => \(substr $$sref,
      $pos,(length $$sref) - $pos

    ),

    cnt  => {},

  };


  # read header
  my ($ct,@cnt)=bunpack(
    $self->{head}->[0],$e->{src},
    int @{$self->{head}}-1

  );

  # ^get read sizes
  map {
    $e->{cnt}->{$ARG}
  = shift @$ct

  } @{$self->{order}};

  # ^get reused sizes
  map {
    $e->{cnt}->{$ARG}
  = $e->{cnt}{$self->{rehead}->{$ARG}}

  } keys %{$self->{rehead}};


  # walk elems
  my $idex=0;

  return map {

    $e->{key} => $self->_proc_elem(

      \&_unpack_struc,
      \&_unpack_prims,

      $e,$idex++

    ),

  } @{$self->{order}};

};

# ---   *   ---   *   ---
# ^Arstd::Bitformat guts

sub _unpack_struc($self,$e) {

  my $cnt=1;

  if(exists $e->{cnt}->{$e->{key}}) {
    $cnt=$e->{cnt}->{$e->{key}};

  };

  my ($out,$len)=$e->{fmat}->from_bytes(
    $e->{src},0,$cnt

  );

  return $out;

};

# ---   *   ---   *   ---
# ^prim guts

sub _unpack_prims($self,$e) {

  my $cnt=1;

  if(exists $e->{cnt}->{$e->{key}}) {
    $cnt=$e->{cnt}->{$e->{key}};

  };

  my ($ct,@cnt)=bunpack(
    $e->{fmat},$e->{src},$cnt

  );

  return $ct;

};

# ---   *   ---   *   ---
# write to buff

sub to_bytes($self,%data) {

  # bind ctx
  my $e={

    key   => $NULLSTR,
    fmat  => $NULLSTR,

    src   => \%data,
    dst   => $NULLSTR,

    cnt   => {},
    total => 0,

  };

  # load header keys
  my @keys=@{$self->{head}};
  shift @keys;

  # ^pass to counter
  $e->{cnt}={map {$ARG=>0} @keys};


  # walk elems
  my $idex=0;

  map { $self->_proc_elem(

    \&_pack_struc,
    \&_pack_prims,

    $e,$idex++

  )} @{$self->{order}};


  # get ordered counters
  my @cnt=map {$e->{cnt}->{$ARG}} @keys;

  # ^pre-pend counters as header
  my ($ct,@len)=bpack(
    $self->{head}->[0] => @cnt

  );


  # ^cat to final
  $e->{total} += $len[-1];
  $e->{dst}    = join $NULLSTR,@$ct,$e->{dst};


  return ($e->{dst},$e->{total});

};

# ---   *   ---   *   ---
# ^Arstd::Bitformat guts

sub _pack_struc($self,$e) {

  # record elem count writ
  my @data = @{$e->{src}->{$e->{key}}};
  my $cnt  = int @data;

  if(exists $e->{cnt}->{$e->{key}}) {
    $e->{cnt}->{$e->{key}}=$cnt;

  };


  # ^get bytearray for elem
  my ($ct,$len)=$e->{fmat}->to_bytes(@data);

  $e->{total} += $len;
  $e->{dst}   .= $ct;

};

# ---   *   ---   *   ---
# ^prim guts

sub _pack_prims($self,$e) {

  # record elem count writ
  my @data = @{$e->{src}->{$e->{key}}};
  my $cnt  = int @data;

  if(exists $e->{cnt}->{$e->{key}}) {
    $e->{cnt}->{$e->{key}}=$cnt;

  };


  # ^get bytearray for elem
  my ($ct,@len)=bpack(
    $e->{fmat} => @data

  );

  $e->{total} += $len[-1];
  $e->{dst}   .= join $NULLSTR,@$ct;

};

# ---   *   ---   *   ---
# test

use Fmat;

my $bfmat=Arstd::Bitformat->new(
  b0 => 7,
  b1 => 1,

);

my $ice=Arstd::Struc->new(
  f0 => 'byte * [byte]',
  f1 => [$bfmat => '^f0'],

);

my ($buf,$len) = $ice->to_bytes(

  f1=>[
    {b0=>0x3F,b1=>0x00},
    {b0=>0x20,b1=>0x01},

  ],

  f0=>[0x24,0x24],

);

my @ar = $ice->from_bytes(\$buf,0);
fatdump(\[@ar]);

# ---   *   ---   *   ---
1; # ret
