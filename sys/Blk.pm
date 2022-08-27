#!/usr/bin/perl
# ---   *   ---   *   ---
# BLOCK
# A handful of memory
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Blk;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Carp;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::Hash;
  use Arstd::IO;

  use parent 'St';

  use Type;
  use Ptr;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    -types=>$Type::Table,
    -blocks=>{},

  }};

  Readonly our $HEADER=>$Type::Table->nit(

    'Blk::HEADER',[

      wide=>'dom',
      wide=>'sigil',

      half=>'NID',
      word=>'stride',

    ]

  );

  Readonly our $BEG_SEQ=>0x2B24;
  Readonly our $END_SEQ=>0x3E3B;

  Readonly our $DOM=>0x4D45;
  Readonly our $SIGIL=>0x4D42;

# ---   *   ---   *   ---
# global state

  our $Non;
  our $Sys_Frame;

# ---   *   ---   *   ---
# shut up, I target 64-bit

BEGIN {

  $SIG{__WARN__}=sub {
    my $warn=shift;
    return if $warn=~
      m/32 non-portable/;

    warn $warn;

  };

};

# ---   *   ---   *   ---
# ensure the existence of non

sub import($class) {

  $Sys_Frame=$class->get_frame();

  if(!defined $Non) {
    $Non=$Sys_Frame->nit(undef,'non');

  };

};

# ---   *   ---   *   ---
# cats parent values recursively

sub ances($self) {

  my $name=$self->{name};

  while($self->{parent}) {
    $name=$self->{parent}->{name}.q{@}.$name;
    $self=$self->{parent};

    if(!defined $self) {last};

  };

  return $name;

};

# ---   *   ---   *   ---
# setter/shorthands

sub set_header($self,$name,%O) {

  # defaults
  $O{N}//=0;
  $O{ID}//=0;

  my $ptr=$self->{elems}->{$name};
  $ptr=$ptr->{by_name}->[0];

  ${$ptr->{NID}}|=($O{N}<<28)|$O{ID};

};

# ---   *   ---   *   ---
# constructor

sub nit(

  # passed implicitly
  $class,$frame,

  # actual args
  $parent,
  $name,

  $attrs=0b000,

) {

  # get dom && sigil
  my $pkg=$frame->{-owner_kls};

  no strict;
  my $dom=${$pkg.'::DOM'};
  my $sigil=${$pkg.'::SIGIL'};

  use strict;

  errout(

    q[Can't make Block: ].

    q[ Package '%s' lacks DOM and/or SIGIL].
    q[ in it's ROM sect],

    args=>[$pkg],
    lvl=>$AR_FATAL,

  ) unless defined $dom && defined $sigil;

# ---   *   ---   *   ---

  my $blk=bless {

    name=>$name,

    size=>0,

    mem=>q{},
    seg=>{},
    idex=>0,

    parent=>$parent,
    children=>[],

    attrs=>$attrs,
    frame=>$frame,

  },$class;

  $blk->{elems}=Ptr->new_frame(
    -memref=>\$blk->{mem},
    -types=>$frame->{-types},

  );

# ---   *   ---   *   ---
# redecl guard

  my $key=$blk->ances();

  if(exists $frame->{-blocks}->{$key}) {

    errout(

      q{Ilegal operation: }.
      q{redeclaration of block '%s'},

      args=>[$key],
      lvl=>$AR_FATAL,

    );

  };

  $frame->{-blocks}->{$key}=$blk;

# ---   *   ---   *   ---
# initialized from instance

  if(defined $parent) {

    $blk->{idex}=int(@{
      $parent->{children}

    });

    push @{$parent->{children}},$blk;

    my $ptr=$parent->alloc($name,$HEADER);
    $ptr->setv($dom,$sigil);

# ---   *   ---   *   ---
# is root block

  } else {
    ;

  };

  return $blk;

};

# ---   *   ---   *   ---
# get block size of N instances of type

sub align($self,$type,$cnt) {

  my $types=$self->{frame}->{-types};
  my $alignment=$types->{unit}->{size};

  my $elem_sz=$type->{size};

  my $mult=int(($elem_sz/$alignment)+0.9999);
  $mult*=$cnt;

  return ($mult,$mult*$alignment);

};

# ---   *   ---   *   ---
# ^same, precalc'd total

sub align_sz($self,$sz) {

  my $types=$self->{frame}->{-types};
  my $alignment=$types->{unit}->{size};

  my $mult=int(($sz/$alignment)+0.9999);

  return ($mult,$mult*$alignment);

};

# ---   *   ---   *   ---
# grow block by an aligned amount

sub grow($self,$mult) {

  my $types=$self->{frame}->{-types};
  my $word_sz=$types->{word}->{size};
  my $alignment=$types->{unit}->{size};

  my $fmat=$Type::PACK_SIZES->{$word_sz*8};

  $self->{mem}.=(

    pack "$fmat>"x($mult*2),
    map {$FREEBLOCK} (0..($mult*2)-1)

  );

  my $prev_top=$self->{size}*$alignment;
  $self->{size}+=$mult;

  return $prev_top;

};

# ---   *   ---   *   ---
# ^inverse

sub shrink($self,$mult) {

  my $types=$self->{frame}->{-types};
  my $alignment=$types->{unit}->{size};

  my $top=$self->{size};

  $self->{mem}=substr

    $self->{mem},
    0,$top-($alignment*$mult)

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

    my $me="\n<".$self->ances().">\n";
    print {$FH} (join $NULLSTR,$me);

    my @ptrs=$self->{elems}->list_by_offset();

    for my $ptr(@ptrs) {
      $ptr->prich(%O);

    };

    unshift @pending,@{$self->{children}};

  };

  print {$FH} "\n";

};

# ---   *   ---   *   ---
1; # ret
