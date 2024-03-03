#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M PTR
# Memory reference
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::ptr;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use Arstd::IO;

  use parent 'A9M::component';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $DEFAULTS=>{

    type   => $Type::DEFAULT,

    ptr_t  => undef,
    segid  => 0x00,
    addr   => 0x00,
    len    => 0,

    mcid   => 0,

  };

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {


  # defaults
  $class->defnit(\%O);
  $O{segcls} //= caller;


  # make ice
  my $self=bless \%O,$class;


  return $self;

};

# ---   *   ---   *   ---
# get container for value

sub getseg($self) {

  my $class = $self->{segcls};
  my $idex  = $self->{segid};
  my $frame = $class->get_frame($self->{mcid});

  return $frame->getseg($idex);

};

# ---   *   ---   *   ---
# interprets value as an addr

sub read_ptr($self) {

  # get ctx
  my $seg = $self->getseg();
  my $mc  = $seg->getmc();

  # get saved addr
  my $ptrv = $seg->dload(
    $self->{ptr_t},
    $self->{addr}

  );


  # ^unroll and give
  return $mc->decode_ptr($ptrv);

};

# ---   *   ---   *   ---
# put value

sub store($self,$value,%O) {


  # defaults
  $O{deref} //= 1;

  # dst vars
  my $seg;
  my $off;


  # write at [value]?
  if($O{deref} && $self->{ptr_t}) {
    ($seg,$off)=$self->read_ptr();

  # ^nope, use own addr
  } else {
    $seg=$self->getseg();
    $off=$self->{addr};

  };


  # give bytes written
  my $len=$seg->dstore(

    $self->{type},
    $value,

    $off,

  );

  $self->{len}=$len;
  return $len;

};

# ---   *   ---   *   ---
# ^fetch

sub load($self,%O) {

  # defaults
  $O{deref} //= 1;

  # src vars
  my $seg;
  my $off;


  # read from [value]?
  if($O{deref} && $self->{ptr_t}) {
    ($seg,$off)=$self->read_ptr();


  # ^nope, use own addr
  } else {
    $seg=$self->getseg();
    $off=$self->{addr};

  };


  # fetch and give
  $seg->dload($self->{type},$off);

};

# ---   *   ---   *   ---
# get absolute address of pointer

sub absloc($self,%O) {


  # defaults
  $O{deref} //= 1;

  # get ctx
  my $off=$self->{addr};
  my $seg=$self->getseg();

  # use addrof [value]?
  if($O{deref} && $O{ptr_t}) {
    ($seg,$off)=$self->read_ptr();

  };


  # give segment base plus relative
  return $seg->absloc() + $off;


};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {


  # I/O defaults
  my $out=ioprocin(\%O);


  # get value as a primitive
  my $type  = ($self->{ptr_t})
    ? $self->{ptr_t}
    : $self->{type}
    ;

  my $value = $self->load();

  my $pad   = 2 * ($type->{sizep2}+1);
     $pad   = 16 if $pad > 16;
     $pad   = "%0${pad}X";


  # have vector?
  if(is_arrayref($value)) {

    my $mc  = $self->getmc();
    my $imp = $mc->{ISA}->imp();

    my $fn  = $imp->flatten($type->{sizebs});


    $value =

      join ' ',
      map  {sprintf $pad,$ARG}

      $imp->copera($fn,$value);


  # have ptr?
  } elsif($self->{ptr_t}) {
    my $addr=$self->load(deref=>0);
    $value=sprintf "*$pad -> $pad",$addr,$value;


  # have decimals?
  } elsif(Type->is_real($type)) {
    $value=sprintf "%.4f",$value;


  # have string?
  } elsif(Type->is_str($type->{name})) {
    $value="\"$value\"";

  # plain value?
  } else {
    $value=sprintf $pad,$value;

  };


  # make repr
  push @$out,sprintf
    "$type->{name} [%04X] -> $value",
    $self->{addr};


  # ^catp and give
  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
