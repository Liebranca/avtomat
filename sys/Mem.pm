#!/usr/bin/perl
# ---   *   ---   *   ---
# MEM
# Memory!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mem;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Carp;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::Array;
  use Arstd::Hash;
  use Arstd::IO;

  use Type;
  use Ptr;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.3;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    -types    => $Type::Table,
    -blocks   => {},

    -autoload => [qw(get_pkg_info)],

  }};

  Readonly our $HEADER=>$Type::Table->nit(

    'Mem::HEADER',[

      wide=>'dom',
      wide=>'sigil',

    ]

  );

  Readonly our $BEG_SEQ => 0x2B24;
  Readonly our $END_SEQ => 0x3E3B;

  Readonly our $DOM     => 0x4D45;
  Readonly our $SIGIL   => 0x4D42;

# ---   *   ---   *   ---
# GBL

  our $Non;
  our $Sys_Frame;

# ---   *   ---   *   ---
# ^get reference to root blk

sub get_nref($class) {

  no strict 'refs';
  my $nref=\${"$class\::Non"};

  return $nref;

};

# ---   *   ---   *   ---
# shut up, I target 64-bit

BEGIN {

  $SIG{__WARN__}=sub {
    my $warn=shift;
    return if $warn=~ m[32 non-portable];

    warn $warn;

  };

};

# ---   *   ---   *   ---
# ensure the existence of non

sub import($class) {

  $Sys_Frame=$class->get_frame();
  my $nref=$class->get_nref();

  if(! defined $$nref) {
    $$nref=$Sys_Frame->nit(undef,'non');

  };

};

# ---   *   ---   *   ---
# cats parent values recursively

sub ances($self) {

  my $name=$self->{name};

  while($self->{parent}) {
    $name=$self->{parent}->{name}.q{::}.$name;
    $self=$self->{parent};

    last if ! defined $self;

  };

  return $name;

};

# ---   *   ---   *   ---
# cstruc

sub nit(

  # implicit
  $class,$frame,

  # actual
  $parent,
  $name,

  $attrs=0b000,

) {

  # make ice
  my $self=bless {

    name     => $name,

    size     => 0,

    buf      => q{},
    seg      => {},
    idex     => 0,

    parent   => $parent,
    children => [],

    attrs    => $attrs,
    frame    => $frame,

  },$class;

  $self->register();

  return $self;

};

# ---   *   ---   *   ---
# ^from ice

sub init($self,$name,$attrs=0b0000) {
  $self->{frame}->nit($self,$name,$attrs);

};

# ---   *   ---   *   ---
# ^crux

sub new($class,$name,$attrs=0b0000) {
  my $nref=$class->get_nref();
  return $$nref->init($name,$attrs);

};

# ---   *   ---   *   ---
# retrieve and validate Mem
# vars from pkg ROM

sub get_pkg_info($class,$frame) {

  # get dom && sigil
  my $pkg=$frame->{-owner_kls};

  no strict;
  my $dom   = ${"$pkg\::DOM"};
  my $sigil = ${"$pkg\::SIGIL"};

  use strict;

  # ^validate
  errout(

    q[Can't make Block: ].

    q[ Package '%s' lacks DOM and/or SIGIL].
    q[ in it's ROM sect],

    args => [$pkg],
    lvl  => $AR_FATAL,

  ) unless defined $dom && defined $sigil;

  return ($dom,$sigil);

};

# ---   *   ---   *   ---
# put reference to block
# within frame
#
# also ensures a block with
# this name cannot be redeclared

sub register($self) {

  my $f   = $self->{frame};
  my $key = $self->ances();

  # validate && write blk header
  my ($dom,$sigil)=$f->get_pkg_info();
  $self->validate_ances($dom,$sigil);

  # redecl guard
  errout(

    q{Ilegal operation: }.
    q{redeclaration of block '%s'},

    args => [$key],
    lvl  => $AR_FATAL,

  ) if exists $f->{-blocks}->{$key};

  # save reference
  $f->{-blocks}->{$key}=$self;

  # enable ptrs for block
  $self->{elems}=Ptr->new_frame(
    -memref => \$self->{buf},
    -types  => $f->{-types},

  );

};

# ---   *   ---   *   ---
# ^validaes a blks ancestry

sub validate_ances($self,$dom,$sigil) {

  my $par=$self->{parent};

  # nit from ice
  if(defined $self->{parent}) {

    $self->{idex}=int(@{
      $par->{children}

    });

    push @{$par->{children}},$self;

    my $ptr=$par->alloc($self->{name},$HEADER);
    $ptr->setv($dom,$sigil);

  # ^is root block
  } else {
    ;

  };

};

# ---   *   ---   *   ---
# get block size of N instances of type

sub align($self,$type,$cnt) {

  my $types   = $self->{frame}->{-types};
  my $align   = $types->{unit}->{size};

  my $elem_sz = $type->{size};

  my $mult=int_urdiv(
    $elem_sz,$align

  ) * $cnt;

  return ($mult,$mult*$align);

};

# ---   *   ---   *   ---
# ^same, precalc'd total

sub align_sz($self,$sz) {

  my $types = $self->{frame}->{-types};
  my $align = $types->{unit}->{size};

  my $mult  = int_urdiv($sz,$align);

  return ($mult,$mult*$align);

};

# ---   *   ---   *   ---
# grow block by an aligned amount

sub grow($self,$mult) {

  my $types   = $self->{frame}->{-types};
  my $word_sz = $types->{word}->{size};
  my $align   = $types->{unit}->{size};

  my $fmat    = $Type::PACK_SIZES->{$word_sz*8};

  $self->{buf}.=(
    pack "$fmat>"x($mult*2),
    map {$FREEBLOCK} (0..($mult*2)-1)

  );

  my $prev_top=$self->{size}*$align;
  $self->{size}+=$mult;

  return $prev_top;

};

# ---   *   ---   *   ---
# ^iv

sub shrink($self,$mult) {

  my $types = $self->{frame}->{-types};
  my $align = $types->{unit}->{size};

  my $top   = $self->{size};

  $self->{buf}=substr
    $self->{buf},
    0,$top-($align*$mult)

  ;

  $self->{size}-=$mult;

  # give new top
  return $self->{size};

};

# ---   *   ---   *   ---
# gives references to sections in mem

sub baptize(

  # implicit
  $self,

  # actual
  $name,
  $type,

  $offset,
  $cnt=1

) {

  my $ptr=$self->{elems}->nit(
    $name,$type,$offset,$cnt

  );

  $ptr->flood(0x00);

  return $ptr;

};

# ---   *   ---   *   ---
# hand sect of mem
#
# reuses free ones if avail
# else grow the block

sub alloc($self,$name,$type,$cnt=1) {

  my $seg=$self->{seg};
  my $offset;

  my ($mult,$aligned_sz)=
    $self->align($type,$cnt);

  # check existance of free segment of equal size
  if(exists $seg->{$aligned_sz}) {
    $offset=pop @{$seg->{$aligned_sz}};

    # discard emptied array
    delete $seg->{$aligned_sz}
    unless @{$seg->{$aligned_sz}};

  # ^grow the block if none avail
  } else {
    $offset=$self->grow($mult);

  };

  return $self->baptize(
    $name,$type,$offset,$cnt

  );

};

# ---   *   ---   *   ---
# ^mark previously alloc'd sect
# as avail for reuse

sub free($self,$name) {

  my $ptr=$self->{elems}->{$name};
  $ptr->flood($FREEBLOCK);

  my ($mult,$aligned_sz)=$self->align(
    $ptr->{type},
    $ptr->{instance_cnt}

  );

  $self->{seg}->{$aligned_sz}//=[];

  push @{$self->{seg}->{$aligned_sz}},
    $ptr->{offset};

  delete $self->{elems}->{$name};

};

# ---   *   ---   *   ---
# debug print

sub prich($self,%O) {

  # opt defaults
  $O{errout}//=0;

  # select filehandle
  my $FH=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  my @pending=($self);
  while(@pending) {

    my $self=shift @pending;

    # put name of blk on screen
    my $me="\n<".$self->ances().">\n";
    print {$FH} (join $NULLSTR,$me);

    # prich out ptrs to blk
    my @ptrs=$self->{elems}->list_by_offset();
    map {$ARG->prich(%O)} @ptrs;

    # ^put sub-blocks in Q
    unshift @pending,@{$self->{children}};

  };

  print {$FH} "\n";

};

# ---   *   ---   *   ---
1; # ret
