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
package Peso::Type;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

  use Frame;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# constructors

sub new_frame($class,@args) {

  return Frame::new(
    class=>$class

  );

};

# ---   *   ---   *   ---

sub nit($class,$frame,$name,$elems,%O) {

  # defaults
  $O{floating}//=0;
  $O{unsigned}//=0;
  $O{memaddr}//=0;

# ---   *   ---   *   ---

  my $size=0;
  my $count=0;

  my $fields={};

# ---   *   ---   *   ---
# struct format:
#
#   > 'type_name'=>[
#
#   >   ['type_name','elem_name']
#   >   ...
#
#   >  ];

  if(length ref $elems) {

    for my $elem(@$elems) {

      my $elem_type=$elem->[0];
      my $elem_name=$elem->[1];

      $fields->{$elem_name}=$elem_type;
      $size+=$frame->{$elem_type}->size;

      $count++;

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

  if($O{floating}) {
    $name.=' float';

  } elsif($O{unsigned}) {
    $name='u'.$name;

  };

  if($O{memaddr}) {
    $name.=' ptr';

  };

# ---   *   ---   *   ---

  my $type=$frame->{$name}={

    size=>$size,
    elem_count=>$count,

    fields=>$fields,

    %O,

  };

  return $type;

};

# ---   *   ---   *   ---
# ROM

  our $TABLE;INIT {

  my $table={

    # primitives
    byte=>1,
    wide=>2,
    word=>4,
    long=>8,

    # ptrs align to half
    # regs align to unit
    # bufs align to line
    # mems align to page

    half=>0x0008, # 1  long
    unit=>0x0010, # 2  halves
    line=>0x0040, # 4  units
    page=>0x1000, # 64 lines

# ---   *   ---   *   ---
# function types

    nihil=>8,     # void(*nihil)(void)
    stark=>8,     # void(*stark)(void*)

    signal=>8,    # int(*signal)(int)

  };

# ---   *   ---   *   ---

  my $F=Peso::Type->new_frame();

  for my $key(keys %$table) {

    my $value=$table->{$key};

    my $fptr=int(
      $key=~ m[(?: nihil|stark|signal)]x

    );

    my $t=$F->nit($key,$value);

    if($fptr) {
      $t->{memaddr}=1;
      $t->{unsigned}=1;

    };

# ---   *   ---   *   ---

    if($key=~ m[(?: word|long)]x) {

      $F->nit($key,$value,floating=>1);
      $F->nit(

        $key,$value,

        floating=>1,
        memaddr=>1

      );

    };

# ---   *   ---   *   ---

    if($key=~ m[(?: byte|wide|word|long)]x) {

      $F->nit($key,$value,unsigned=>1);
      $F->nit(

        $key,$value,

        unsigned=>1,
        memaddr=>1

      );

    };

# ---   *   ---   *   ---

  };

  $TABLE=$F;

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
1; # ret
