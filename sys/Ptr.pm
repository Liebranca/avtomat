#!/usr/bin/perl
# ---   *   ---   *   ---
# PTR
# A location in memory
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Ptr;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Bytes;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {
  return {

    -memref=>undef,
    -types=>undef,
    -autoload=>[qw(

      list_by_offset

    )],

  }};

# ---   *   ---   *   ---
# lock pointer onto the set address

sub point($self) {

  my $memref=$self->{frame}->{-memref};
  my $offset=$self->{offset};

  # we'll need this later
  my $base_offset=$offset;

  my $type=(defined $self->{casted})
    ? $self->{casted}
    : $self->{type}
    ;

  my $types=$self->{frame}->{-types};
  my $word_sz=$types->{word}->{size};
  my $alignment=$types->{unit}->{size};

# ---   *   ---   *   ---

  my @elems=();

  # is struct
  if(@{$type->{fields}}) {
    @elems=(@{
      $type->{fields}

  }) x $self->{instance_cnt};

  # is primitive
  } else {

    @elems=(
      $type->{size},
      $type->{name},

    ) x $self->{instance_cnt};

  };

# ---   *   ---   *   ---
# for each struct

  for my $i(0..$self->{instance_cnt}-1) {
    my $bn=$self->{by_name}->[$i]={};

# ---   *   ---   *   ---
# for each primitive

    for my $j(0..$type->{elem_count}-1){

      my $size=shift @elems;
      my $name=shift @elems;

      # point to section in mem
      my $idex=$j+($i*$type->{elem_count});
      $self->{buff}->[$idex]=\(vec(

        $$memref,

        # align offset
        int(($offset/$size)+0.9999),$size*8

      ));

      # save by-name access
      $bn->{$name}=$self->{buff}->[$idex];

      # go to next chunk
      $offset+=$size;

    };

# ---   *   ---   *   ---
# align elements; pads between structs if needed

    $self->{buff_sz}=int(

      (($offset-$self->{offset})
      /$alignment

    )+0.9999);

    # adjust byte offset to top
    $offset=$base_offset
      +($self->{buff_sz}*$alignment);

  };

};

# ---   *   ---   *   ---
# constructor

sub nit(

  # implicit
  $class,$frame,

  # actual
  $name,
  $type,
  $offset,
  $cnt,

) {

  my $ptr=bless {

    id=>$name,

    type=>$type,
    casted=>undef,

    offset=>$offset,
    instance_cnt=>$cnt,

    # by-index access
    buff=>[],
    buff_sz=>0,

    # by-name access
    by_name=>[],

    frame=>$frame,

  },$class;

  $ptr->point();
  $frame->{$name}=$ptr;

  return $ptr;

};

# ---   *   ---   *   ---

sub buf($self,$idex=undef) {

  if(!defined $idex) {
    return (@{$self->{buff}});

  } else {
    return $self->{buff}->[$idex];

  };

};

# ---   *   ---   *   ---
# gives each element in buffer as it's own ptr

sub subdiv($self) {

  my $types=$self->{frame}->{-types};
  my $alignment=$types->{unit}->{size};

  my $elem_sz=$self->{type}->{size};

  my $type=$self->{type};
  my @buff=@{$self->{buff}};

# ---   *   ---   *   ---

  my @copies=();

  for my $i(0..$self->{instance_cnt}-1) {

    my $beg=$i*$type->{elem_count};
    my $end=($i+1)*$type->{elem_count};

    push @copies,bless {

      type=>$self->{type},
      casted=>$self->{casted},

      offset=>$self->{offset}+($elem_sz*$i),

      instance_cnt=>1,

      buff=>[@buff[$beg..$end-1]],

      buff_sz=>int(($elem_sz/$alignment)+0.9999),
      by_name=>[$self->{by_name}->[$i]],

      frame=>$self->{frame},

    },$self->get_class();

  };

  return @copies;

};

# ---   *   ---   *   ---
# flood fill word-sized chunks

sub flood($self,$value) {

  my $memref=$self->{frame}->{-memref};
  my $types=$self->{frame}->{-types};

  my $word_sz=$types->{word}->{size};
  my $offset=$self->{offset}/$word_sz;

  for my $half(0..($self->{buff_sz}*2)-1) {
    vec($$memref,$offset,$word_sz*8)=$value;
    $offset++;

  };

};

# ---   *   ---   *   ---

sub setv($self,@data) {

  my $i=0;

  while(

     defined $self->{buff}->[$i]
  && defined $data[$i]

  ) {

    ${$self->{buff}->[$i]}=$data[$i];
    $i++;

  };

};

# ---   *   ---   *   ---

sub encode($self,%data) {

  my $type=$self->{type};
  $self->strcpy($type->encode(%data));

};

# ---   *   ---   *   ---
# writes a string to memory

sub strcpy($self,$data,%O) {

  # defaults
  $O{wide}//=0;
  $O{disp}//=0;

# ---   *   ---   *   ---

  my $sz=8+(8*$O{wide});
  my @chars=lmord(

    $data,

    width=>$sz,
    elem_sz=>$sz,

    rev=>0

  );

# ---   *   ---   *   ---

  my $memref=$self->{frame}->{-memref};
  my $offset=$self->{offset};

  # halve offset for wide strings
  $offset=int($offset/(1+$O{wide}));

  # displacement assumed relative to char size
  $offset+=$O{disp};

  # copy bytes
  map {vec(

    $$memref,
    $offset++,
    $sz

  )=$ARG} @chars;

};

# ---   *   ---   *   ---
# returns a slice of pointed memory

sub rawdata($self,%O) {

  # defaults
  $O{beg}//=0;
  $O{end}//=-1;

  my $memref=$self->{frame}->{-memref};
  my $offset=$self->{offset};

  my $size;

  # full read
  if($O{beg}==0 && $O{end}<0) {

    my $types=$self->{frame}->{-types};
    my $alignment=$types->{unit}->{size};

    $size=$self->{buff_sz}*$alignment;

  # partial read
  } else {

    my $elem_sz=$self->{type}->{size};

    $offset+=$O{beg}*$elem_sz;
    $size=($O{end}-$O{beg})*$elem_sz;

  };

  return substr $$memref,$offset,$size;

};

# ---   *   ---   *   ---

sub decode($self) {

  my $out=[];
  my $type=$self->{type};

  for my $i(0..$self->{instance_cnt}-1) {

    push @$out,$type->decode(
      $self->rawdata(beg=>$i,end=>$i+1)

    );

  };

  return $out;

};

# ---   *   ---   *   ---

sub list_by_offset($class,$frame) {

  my @ptrs=grep {

    Ptr->is_valid($ARG)

  } values %{$frame};

  @ptrs=sort {

    $a->{offset}<=>$b->{offset}

  } @ptrs;

  return @ptrs;

};

# ---   *   ---   *   ---

sub prich($self,%O) {

  # opt defaults
  $O{errout}//=0;

  my $types=$self->{frame}->{-types};
  my $alignment=$types->{unit}->{size};

  my $memref=$self->{frame}->{-memref};
  my $sz=$self->{buff_sz};

  my @me=();
  my $psize=$Type::PACK_SIZES->{64};

  my $elem_sz=$self->{type}->{size};

  my $elem_i=1;
  my $offset=0;

# ---   *   ---   *   ---

  for my $i(0..($sz*2)-1) {
    my $db=substr $$memref,$i*8,8;
    my $str=unpack "$psize>",$db;

    my $nl=$NULLSTR;
    my $tab=$NULLSTR;

    # is uneven
    if($i&0b1) {

      if($i==1) {

        $nl=

          (sprintf ': [%04X]',0).

          " $self->{type}->{name} ".
          "'$self->{id}'\n"

        ;

      } elsif($offset>=$elem_sz) {
        $nl=sprintf ": [%04X]\n",$elem_i;
        $elem_i++;
        $offset=0;

      } else {
        $nl="\n";

      };

      $nl.="\n" if !($i%7);

    } else {
      $tab=q{  0x};

    };

    $offset+=8;

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
