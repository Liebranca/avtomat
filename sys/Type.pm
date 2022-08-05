#!/usr/bin/perl
# ---   *   ---   *   ---
# TYPE
# So you can redefine primitives
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Type;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

  use parent 'St';
  use Vault 'ARPATH';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.03.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {{}};

  our $Indirection_Key=[qw(ptr pptr xptr)];

  our $Table=Vault::cached(

    'Table',\$Table,

    \&gen_type_table,

    # primitives

    byte=>1,
    wide=>2,
    long=>4,
    word=>8,

    # measuring

    unit=>0x0010, # 2  words
    line=>0x0040, # 4  units
    page=>0x1000, # 64 lines

    # function types

    nihil=>8,     # void(*nihil)(void)
    stark=>8,     # void(*stark)(void*)

    signal=>8,    # int(*signal)(int)

  );

# ---   *   ---   *   ---
# constructor

sub nit(

  # implicit
  $class,$frame,

  # actual
  $name,
  $elems,

  # options
  %O

) {

  # defaults
  $O{real}//=0;
  $O{sign}//=0;
  $O{addr}//=0;

# ---   *   ---   *   ---

  my $size=0;
  my $count=0;

  my $fields=[];

# ---   *   ---   *   ---
# struct format:
#
#   > 'type_name'=>[
#
#   >   'type_name'=>'elem_name'
#   >   ...
#
#   >  ];

  if(length ref $elems) {

    while(@$elems) {

      my $elem_type=shift @$elems;
      my $elem_name=shift @$elems;

      my $elem_sz=$frame->{$elem_type}->{size};

      my $mult=1;
      if($elem_name=~ s[\((\d+)\)][]) {
        $mult=$1;

      };

      for my $i(0..$mult-1) {

        my $n=($i>0)
          ? "$elem_name+$i"
          : $elem_name
          ;

        push @$fields,$elem_sz,$n;
        $size+=$frame->{$elem_type}->{size};

        $count++;

      };

    };

# ---   *   ---   *   ---
# primitive format:
#
#   > 'type_name'=>size

  } else {

    $count=1;
    $size=$elems;

  };

# ---   *   ---   *   ---
# ugly arse specifiers...

  if($O{sign}) {
    $name="s$name";

  };

  if($O{addr}) {

    my $spec=$Indirection_Key->[$O{addr}-1];

    $name.=" $spec";

  };

# ---   *   ---   *   ---

  my $type=$frame->{$name}={

    name=>$name,
    size=>$size,
    elem_count=>$count,

    fields=>$fields,

    %O,

  };

  return $type;

};

# ---   *   ---   *   ---
# fills out table of type variations
# these exist mostly to ease interfacing
# with typed languages

sub gen_type_table(%table) {

  my $F=Type->new_frame();

  for my $indlvl(1..3) {
  for my $key(keys %table) {

    my $value=$table{$key};

    my $fptr=int(
      $key=~ m[(?: nihil|stark|signal)]x

    );

    my $t=$F->nit($key,$value);

    if($fptr) {
      $t->{addr}=$indlvl;
      $t->{sign}=0;

    };

# ---   *   ---   *   ---
# generate floating types

    if($key=~ m[(?: long|word)]x) {

      my $real_type=(
        'real','daut'

      )[$key eq 'word'];

      $F->nit($real_type,$value,real=>1);
      $F->nit(

        $real_type,$value,

        real=>1,
        addr=>$indlvl

      );

    };

# ---   *   ---   *   ---
# generate signed and pointers

    if($key=~ m[(?: byte|wide|long|word)]x) {

      $F->nit($key,$value,sign=>1);
      $F->nit(

        $key,$value,

        sign=>0,
        addr=>$indlvl

      );

    };

# ---   *   ---   *   ---

  }};

  return $F;

};

# ---   *   ---   *   ---
1; # ret
