#!/usr/bin/perl
# ---   *   ---   *   ---
# ST
# Fundamental structures
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package St;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;
  use English qw(-no_match_vars);

  use Scalar::Util qw(blessed reftype);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Frame;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.4;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {{}};

# ---   *   ---   *   ---
# global state

  my $Frames={};

# ---   *   ---   *   ---
# is obj instance of class

sub is_valid($kind,$obj) {

  return
     defined blessed($obj)
  && int $obj->isa($kind)

  ;

};

# ---   *   ---   *   ---
# ^same, but in the strict sense!
#
# obj must be *exactly*
# an ice of type -- derived
# classes won' pass this test

sub is_iceof($kind,$obj) {

  return
     $kind->is_valid($obj)
  && $kind eq ref $obj
  ;

};

# ---   *   ---   *   ---
# what clas obj is an instance of

sub get_class($obj) {return ref $obj};

# ---   *   ---   *   ---
# initialize struct elements
# to default values

sub defnit($class,$href) {

  no strict 'refs';

    my $defs=${"$class\::DEFAULTS"};

    for my $key(keys %$defs) {
      $href->{$key} //= $defs->{$key};

    };

  use strict 'refs';

};

# ---   *   ---   *   ---
# return default frame
# for class or instance
#
# always assumed to be at the top
# of the global state hierarchy

sub get_gframe($class) {

  if(length ref $class) {
    my $self = $class;
    $class   = $self->get_class();

  };

  return $class->get_frame(0);

};

# ---   *   ---   *   ---
# make instance container

sub new_frame($class,%O) {

  # general defaults
  $O{-owner_kls}  //= (caller)[0];
  $O{-force_idex} //= 0;
  $O{-prev_owners}  = [];

  # ^fetch class-specific defaults!
  my $vars=$class->Frame_Vars();
  map {$O{$ARG}//=$vars->{$ARG}} keys %$vars;

  # ^assign owner class
  $O{-class}=$class;

  # ensure we have an icebox ;>
  $Frames->{$class}//=[];
  my $icebox=$Frames->{$class};


  # remember requested idex
  my $idex=$O{-force_idex};
  delete $O{-force_idex};

  # ^make ice
  my $frame=Frame->_new(%O);

  # no idex asked for?
  if($idex) {

    my $i    = 0;
       $idex = undef;

    # get first undefined slot
    map {
      $idex //= $i
      if ! $icebox->[$i++]

    } @$icebox;

    # ^top of array if none avail!
    $idex //= $i;

  };


  # save ice and give
  $Frames->{$class}->[$idex]=$frame;

  return $frame;

};

# ---   *   ---   *   ---
# ^get existing or make new

sub get_frame($class,$i=0) {

  my $out;

  if(! exists $Frames->{$class}) {

    $out=$class->new_frame(
      -owner_kls=>(caller)[0]

    );

  } else {
    $out=$Frames->{$class}->[$i];

  };

  return $out;

};

# ---   *   ---   *   ---
# ^get idex of existing

sub iof_frame($class,$frame) {

  my $ar=$Frames->{$class}
  or croak "No frames avail for $class";

  my ($idex)=grep {
    $ar->[$ARG] eq $frame

  } 0..int(@$ar)-1;

  return $idex;

};

# ---   *   ---   *   ---
# ^get list of existing

sub get_frame_list($class) {
  return @{$Frames->{$class}};

};

# ---   *   ---   *   ---
# get attrs that don't begin
# with a dash

sub nattrs($self) {
  map  {  $ARG  => $self->{$ARG}}
  grep {! ($ARG =~ qr{^\-})} keys %$self;

};

# ---   *   ---   *   ---
1; # ret
