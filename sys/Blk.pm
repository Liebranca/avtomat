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
  use Arstd;

  use parent 'St';

  use Type;
  use Ptr;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $PACK_SIZES=>Arstd::invert_hash({

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

    Arstd::errout(

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
# grow block by some amount
# amount is assumed NOT to be aligned

sub grow($self,$cnt) {

  my $types=$self->{frame}->{-types};

  my $half_sz=$types->{half}->{size};

  my $alignment=$types->{unit}->{size};
  my $mult=1;

  while($cnt>$alignment*$mult) {$mult++};
  $alignment*=$mult;

# ---   *   ---   *   ---
# grow to a multiple of alignment

  my $size=$PACK_SIZES->{$half_sz*8};

  $self->{mem}.=(

    pack "$size>"x($mult*2),
    map {$FREEBLOCK} (0..($mult*2)-1)

  );

  $self->{size}+=$mult;

  return $alignment;

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
