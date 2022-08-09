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
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Hash;
  use Arstd::IO;

  use parent 'St';

  use Type;
  use Ptr;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $PACK_SIZES=>hash_invert({

    'Q'=>64,
    'L'=>32,
    'S'=>16,
    'C'=>8,

  },duplicate=>1);

  sub Frame_Vars($class) {
  return {

    -types=>$Type::Table,
    -blocks=>{},

  }};

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
# constructor

sub nit(

  # passed implicitly
  $class,$frame,

  # actual args
  $parent,
  $name,

  $attrs=0b000,

) {

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

# ---   *   ---   *   ---
# is root block

  } else {
    ;

  };

  return $blk;

};

# ---   *   ---   *   ---

sub align($self,$type,$cnt) {

  my $types=$self->{frame}->{-types};
  my $alignment=$types->{unit}->{size};

  my $total=$type->{size}*$cnt;

  my $mult=int(($total/$alignment)+0.9999);

  return ($mult,$mult*$alignment);

};

# ---   *   ---   *   ---
# grow block by an aligned amount

sub grow($self,$mult) {

  my $types=$self->{frame}->{-types};
  my $word_sz=$types->{word}->{size};
  my $alignment=$types->{unit}->{size};

  my $fmat=$PACK_SIZES->{$word_sz*8};

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

  $ptr->flood(0);

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

  my $mem=$self->{mem};
  my $sz=$self->{size};

  my @me=();
  my $psize=$PACK_SIZES->{64};

# ---   *   ---   *   ---

  for my $i(0..($sz*2)-1) {
    my $db=substr $mem,$i*8,8;
    my $str=unpack "$psize>",$db;

    my $nl=$NULLSTR;
    my $tab=$NULLSTR;

    # is uneven
    if($i&0b1) {
      $nl="\n";

    } else {
      $tab=q{  0x};

    };

    $me[$i]=sprintf $tab."%016X ".$nl,$str;

  };

# ---   *   ---   *   ---

  # select filehandle
  my $FH=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  return print {$FH} (join $NULLSTR,@me);

};

# ---   *   ---   *   ---
1; # ret
