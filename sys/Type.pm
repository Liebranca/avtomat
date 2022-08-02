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
  our $Table=Vault::cached(

    'Table',\$Table,

    \&gen_type_table,

    # primitives

    byte=>1,
    wide=>2,
    word=>4,
    long=>8,

    # measuring

    unit=>0x0010,

    half=>0x0008, # 1/2 unit
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
# the lazy way to do this bit ;>

  if($O{real}) {
    $name.=' float';

  } elsif($O{sign}) {
    $name='s'.$name;

  };

  if($O{addr}) {
    $name.=' ptr';

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
# makes a translation table from
# a language X to peso

sub xltab(%T) {

  state $s_re=qr{\%s}x;
  state $type_re=qr{\$type}x;

  my $ptr_rules=$T{-PTR_RULES};
  my $unsig_rules=$T{-UNSIG_RULES};

  delete $T{-PTR_RULES};
  delete $T{-UNSIG_RULES};

  my $out={};

# ---   *   ---   *   ---

  for my $width(keys %T) {

    my $signed_types=$T{$width}->{sig};
    my $unsigned_types=$T{$width}->{sig};

    for my $type(@$signed_types) {
      $out->{$type}=$width;

# ---   *   ---   *   ---

      if($width=~ m/\s float$/x) {
        my $type_ptr=$ptr_rules->{fmat};

        $type_ptr=~ s/$s_re/$ptr_rules->{key}/;
        $type_ptr=~ s/$type_re/$type/;

        $out->{$type_ptr}="$width ptr";

        next;

      };

# ---   *   ---   *   ---

      my $type_uptr=$NULLSTR;
      my $type_unsig=$unsig_rules->{fmat};

      $type_unsig=~ s/$s_re/$unsig_rules->{key}/;
      $type_unsig=~ s/$type_re/$type/;

      $type_uptr=$type_unsig;
      $out->{$type_unsig}="u$width";

# ---   *   ---   *   ---

      my $type_ptr=$ptr_rules->{fmat};

      $type_ptr=~ s/$s_re/$ptr_rules->{key}/;

      my $tmp=$type_ptr;
      $type_ptr=~ s/$type_re/$type/;
      $tmp=~ s/$type_re/$type_uptr/;

      $type_uptr=$tmp;

      $out->{$type_ptr}="$width ptr";
      $out->{$type_uptr}="u$width ptr";

    };

  };

  return $out;

};

# ---   *   ---   *   ---
# fills out table of type variations
# these exist mostly to ease interfacing
# with typed languages

sub gen_type_table(%table) {

  my $F=Type->new_frame();

  for my $key(keys %table) {

    my $value=$table{$key};

    my $fptr=int(
      $key=~ m[(?: nihil|stark|signal)]x

    );

    my $t=$F->nit($key,$value);

    if($fptr) {
      $t->{addr}=1;
      $t->{sign}=0;

    };

# ---   *   ---   *   ---
# generate floating types

    if($key=~ m[(?: word|long)]x) {

      $F->nit($key,$value,real=>1);
      $F->nit(

        $key,$value,

        real=>1,
        addr=>1

      );

    };

# ---   *   ---   *   ---
# generate signed and pointers

    if($key=~ m[(?: byte|wide|word|long)]x) {

      $F->nit($key,$value,sign=>1);
      $F->nit(

        $key,$value,

        sign=>0,
        addr=>1

      );

    };

# ---   *   ---   *   ---

  };

  return $F;

};

# ---   *   ---   *   ---
1; # ret
