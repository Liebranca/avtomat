#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M
# The Arcane 9 Machine
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Warnme;

  use Arstd::Array;
  use Arstd::PM;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $COMPONENTS => [qw(mem ptr)];

# ---   *   ---   *   ---
# GBL

sub icebox($class) {
  state  $ar=[];
  return $ar;

};

sub ice($class,$idex) {
  return $class->icebox()->[$idex];

};

sub sizeof_segtab($class) {0x10};
sub sizep2_segtab($class) {0x04};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{memroot} //= 'non';


  # get machine id
  my $icebox = $class->icebox();
  my $id     = @$icebox;

  # find components through methods
  my $bk={ map {
    my $fn="get_${ARG}_bk";
    $ARG=>$class->$fn();

  } @$COMPONENTS };


  # make ice
  my $self=bless {

    id  => $id,
    cas => $bk->{mem}->mkroot(
      mcid  => $id,
      label => $O{memroot},

    ),

    segtab   => [(null) x $class->sizeof_segtab()],
    segtab_i => 0x00,

    bk       => $bk,

  },$class;

  # ^add to box
  push @$icebox,$self;


  return $self;

};

# ---   *   ---   *   ---
# resets segment table state

sub reset_segtab($self) {

  $self->{segtab}=[
    (null) x $self->sizeof_segtab()

  ];

  $self->{segtab_i}=0x00;

};

# ---   *   ---   *   ---
# gets idex of segment in
# current configuration of
# segment table

sub segid($self,$seg) {

  # get ctx
  my $tab = $self->{segtab};
  my $top = \$self->{segtab_i};


  # have segment in table?
  my $idex=array_iof(
    $self->{segtab},$seg

  );

  # ^nope, can fit another?
  if(! defined $idex) {


    # ^yes, add new entry
    if($$top < $self->sizeof_segtab()) {
      $idex=$$top;
      $self->{segtab}->[$$top++]=$seg;


    # ^nope, give warning
    } else {
      return warn_full_segtab($self->{id});

    };

  };


  return $idex;

};

# ---   *   ---   *   ---
# ^errme

sub warn_full_segtab($id) {

  warnproc

    "segment table for machine ID "
  . "[num]:%u is full",

    args => [$id],
    give => null

  ;

};

# ---   *   ---   *   ---
# errme for ptr encode/decode

sub badptr($mode) {
  warnproc "cannot $mode pointer",
  give => null;

};

# ---   *   ---   *   ---
# OR together segment:offset

sub encode_ptr($self,$seg,$off) {

  # validate segment
  my $segid = $self->segid($seg);
  return badptr 'encode' if $segid eq null;

  # ^roll and give
  my $bits = $self->sizep2_segtab();
  my $ptrv = $segid | ($off << $bits);


  return $ptrv;

};

# ---   *   ---   *   ---
# ^undo

sub decode_ptr($self,$ptrv) {

  # unroll
  my $bits  = $self->sizep2_segtab();
  my $mask  = (1 << $bits)-1;

  my $segid = $ptrv  & $mask;
  my $off   = $ptrv >> $bits;


  # ^validate and give
  my $seg = $self->{segtab}->[$segid]
  or return badptr 'decode';


  return ($seg,$off);

};

# ---   *   ---   *   ---
# find implementation of
# an individual component

sub get_bk_class($class,$name) {

  my $pkg="A9M\::$name";

  cload  $pkg;
  return $pkg;

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$class->get_bk_class] => q[$class],

  map {["get_${ARG}_bk" => "'$ARG'"]}
  qw  (mem ptr)

);

# ---   *   ---   *   ---
# ^fetch component in use by instance

sub getbk($class,$idex,$name) {

  my $ice = $class->ice($idex);
  my $bk  = $ice->{bk};

  return (exists $bk->{$name})
    ? $bk->{$name}
    : warn_nobk($name)
    ;

};

# ---   *   ---   *   ---
# ^errme

sub warn_nobk($name) {

  Warnme::invalid 'machine component',

  obj  => $name,
  give => null;

};

# ---   *   ---   *   ---
1; # ret
