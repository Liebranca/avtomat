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
  use Bpack;
  use Chk;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::Bitformat;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.7;#b
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
  my $rehead_chk = sub ($cntsz,$idex) {

    if($cntsz=~ s[$rehead_re][]) {
      $rehead->{$keys[$idex]}=$cntsz;

    } else {
      push @head_keys,$keys[$idex];
      push @head_fmat,$cntsz;

    };

  };


  # apply filter to struc format
  @values=map {

    my ($fmat,$cntsz)=@$ARG;

    # have counter?
    $rehead_chk->($cntsz,$idex)
    if defined $cntsz;

    $ARG=$fmat;

    # go next and give
    $idex++;
    $ARG;

  } @values;


  # ^have any header data?
  if(@head_fmat) {
    my $fmat=join ',',@head_fmat;
    unshift @head_keys,$fmat;

  };


  # get value=>(rel fptr)
  my @procs=map {

    (Arstd::Bitformat->is_valid($ARG))
  | ($class->is_valid($ARG) << 1)
  ;

  } @values;


  # get fields that are themselves
  # instances of this class
  my $substruc = {};
     $idex     = 0;

  map {

    $substruc->{$ARG}=$values[$idex]
    if $procs[$idex] & 0x2;

    $idex++;

  } @keys;


  # make ice
  my $self=bless {

    #   size fields to read
    # / size fields to reuse
    head    => \@head_keys,
    rehead  => $rehead,

    # the actual fields
    fmat    => \@values,
    proc    => \@procs,

    # used for walking
    order    => \@keys,
    substruc => $substruc,

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# makes ordered array from
# data hashref

sub ordered($self,$data) {

  return [map {
    $ARG=>$data->{$ARG}

  } '$:head;>',@{$self->{order}}];

};

# ---   *   ---   *   ---
# proto: run F with elem,
# accto elem type

sub _proc_elem($self,$farray,$e,$idex) {

  # get ctx vars
  $e->{key}  = $self->{order}->[$idex];
  $e->{fmat} = $self->{fmat}->[$idex];

  # get func to run
  my $f=$self->{proc}->[$idex];
     $f=$farray->[$f];

  # ^exec
  return $self->$f($e);

};

# ---   *   ---   *   ---
# collapse elem size hash

sub _up_ezycol($e) {

  my $len = 0;
  my @Q   = values %{$e->{ezy}};

  while(@Q) {

    my $i=shift @Q;

    if(is_hashref($i)) {
      push @Q,values %$i;

    } else {
      $len+=$i;

    };

  };


  return $len;

};

# ---   *   ---   *   ---
# read from bytestr

sub from_bytes($self,$rawref) {

  # self->proc[X] is idex to one of
  # these functions
  state $farray=[
    '_unpack_prims',
    '_unpack_struc',
    '_unpack_struc',

  ];


  # bind ctx
  my $e={

    key  => $NULLSTR,
    fmat => $NULLSTR,

    src  => $rawref,

    cnt  => {},
    ezy  => {},

  };


  # read header
  my $b    = {ct=>[],len=>0};
  my @head = @{$self->{head}};

  if(@head) {
    $b = bunpacksu $head[0],$e->{src};
    $e->{ezy}->{'$:head;>'} = $b->{len};

  };


  # ^get read sizes
  map {
    $e->{cnt}->{$ARG}
  = shift @{$b->{ct}}

  } @head[1..$#head];

  # ^get reused sizes
  map {
    $e->{cnt}->{$ARG}
  = $e->{cnt}{$self->{rehead}->{$ARG}}

  } keys %{$self->{rehead}};


  # walk elems
  my $idex=0;

  my $out={ map {
     $e->{key}
  => $self->_proc_elem($farray,$e,$idex++)->{ct},

  } @{$self->{order}} };


  # ^collapse
  return {
    ct  => $out,
    len => _up_ezycol $e,

  };

};

# ---   *   ---   *   ---
# ^consume bytes

sub from_strm($self,$sref,$pos,$nullarg=0) {

  my $rawref=\(substr $$sref,
    $pos,(length $$sref) - $pos

  );

  return $self->from_bytes($rawref);

};

# ---   *   ---   *   ---
# get element count for
# unpacking subroutines

sub _u_get_elem_cnt($e) {

  my $cnt=1;

  if(exists $e->{cnt}->{$e->{key}}) {
    $cnt   = $e->{cnt}->{$e->{key}};
    $cnt //= 1;

  };

  return $cnt;

};

# ---   *   ---   *   ---
# ^prim guts

sub _unpack_prims($self,$e) {

  my $cnt=_u_get_elem_cnt($e);

  my $b=bunpacksu(
    $e->{fmat},$e->{src},0,$cnt

  );

  $e->{ezy}->{$e->{key}}=$b->{len};

  return $b;

};

# ---   *   ---   *   ---
# ^recurse guts
# works for Arstd::Bitformat ;>

sub _unpack_struc($self,$e) {

  my $cnt=_u_get_elem_cnt($e);

  my $b=$e->{fmat}->from_strm(
    $e->{src},0,$cnt

  );

  $e->{ezy}->{$e->{key}}=$b->{len};

  return $b;

};

# ---   *   ---   *   ---
# write to buff

sub to_bytes($self,%data) {


  # self->proc[X] is idex to one of
  # these functions
  state $farray=[
    '_pack_prims',
    '_pack_bitformat',
    '_pack_struc'

  ];


  # bind ctx
  my $e={

    key   => $NULLSTR,
    fmat  => $NULLSTR,

    src   => \%data,
    dst   => $NULLSTR,

    cnt   => {},
    ezy   => {},

  };

  # load header keys
  my @keys=@{$self->{head}};
  shift @keys;

  # ^pass to counter
  $e->{cnt}={map {$ARG=>0} @keys};


  # walk elems
  my $idex=0;

  map {
    $self->_proc_elem($farray,$e,$idex++)

  } @{$self->{order}};


  # get ordered counters
  my @cnt=map {$e->{cnt}->{$ARG}} @keys;


  # ^pre-pend counters as header
  if(@{$self->{head}}) {

    my $b=bpack $self->{head}->[0] => @cnt;

    # ^cat to final
    $e->{ezy}->{'$:head;>'} = $b->{len};
    $e->{dst} = catar $b->{ct},$e->{dst};

  };


  # ^collapse
  return {
    ct  => $e->{dst},
    len => _up_ezycol $e,

  };

};

# ---   *   ---   *   ---
# ^inserts result in existing
# bytestr

sub to_strm($self,$sref,$pos,%data) {

  my $b=$self->to_bytes(%data);
  substr $$sref,$pos,$b->{len},$b->{ct};

  return $b->{len};

};

# ---   *   ---   *   ---
# get element count and
# data for packing subroutines

sub _p_get_elems($e) {

  my @data = @{$e->{src}->{$e->{key}}};
  my $cnt  = int @data;

  if(exists $e->{cnt}->{$e->{key}}) {
    $e->{cnt}->{$e->{key}}=$cnt;
    $cnt //= 1;

  };

  return @data;

};

# ---   *   ---   *   ---
# cat packed to dst

sub _p_cat($e,$b) {
  $e->{ezy}->{$e->{key}} = $b->{len};
  $e->{dst} .= catar $b->{ct};

};

# ---   *   ---   *   ---
# ^prim guts

sub _pack_prims($self,$e) {
  _p_cat $e,bpack $e->{fmat},_p_get_elems($e);

};

# ---   *   ---   *   ---
# ^Arstd::Bitformat guts

sub _pack_bitformat($self,$e) {
  _p_cat $e,$e->{fmat}->to_bytes(_p_get_elems($e));

};

# ---   *   ---   *   ---
# ^recurse guts

sub _pack_struc($self,$e) {
  map {_p_cat $e,$e->{fmat}->to_bytes(%$ARG)}
  _p_get_elems($e);

};

# ---   *   ---   *   ---
1; # ret
