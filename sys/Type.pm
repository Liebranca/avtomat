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

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::Hash;

  use parent 'St';
  use Vault 'ARPATH';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.03.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {{}};

  our $Indirection_Key=[qw(ptr pptr xptr)];

  Readonly our $PACK_SIZES=>hash_invert({

    'Q'=>64,
    'L'=>32,
    'S'=>16,
    'C'=>8,

  },duplicate=>1);

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

    signal=>8,    # uint64_t(*signal)(uint64_t)

  );

  Readonly my $STRTYPE_RE=>qr{_str}x;

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
  $O{str}//=0;

# ---   *   ---   *   ---

  my $size=0;
  my $count=0;
  my $sigil=0;

  my $SIGIL_FLAGS={

    q[sign]=>0x10,
    q[real]=>0x20,
    q[ptr]=>0x40,
    q[str]=>0x80,

  };

  my $fields=[];
  my $subtypes=[];

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

    $sigil|=8|$SIGIL_FLAGS->{ptr};

    while(@$elems) {

      my $elem_type=shift @$elems;
      my $elem_name=shift @$elems;

      my $elem_sz=$frame->{$elem_type}->{size};

      my @names=split $COMMA_RE,$elem_name;
      if(@names>1) {goto MUL_NAMES};

      my $mult=1;
      if($elem_name=~ s[\((\d+)\)][]) {
        $mult=$1;

      };

MUL_VALUES:

      for my $i(0..$mult-1) {

        my $n=($i>0)
          ? "$elem_name+$i"
          : $elem_name
          ;

        push @$fields,$elem_sz,$n;
        $size+=$frame->{$elem_type}->{size};

        $count++;

      };

      push @$subtypes,$elem_type=>$mult;

      goto DONE;

MUL_NAMES:

      for my $name(@names) {

        push @$fields,$elem_sz,$name;
        push @$subtypes,$elem_type=>1;

        $size+=$frame->{$elem_type}->{size};

        $count++;

      };

DONE:

    };

# ---   *   ---   *   ---
# primitive format:
#
#   > 'type_name'=>size

  } else {

    $count=1;
    $size=$elems;

    $sigil=$size

    | ($SIGIL_FLAGS->{sign}*$O{sign})
    | ($SIGIL_FLAGS->{real}*$O{real})

    | ($SIGIL_FLAGS->{ptr}*$O{addr})
    | ($SIGIL_FLAGS->{str}*$O{str})

    ;

  };

# ---   *   ---   *   ---
# ugly arse specifiers...

  if($O{sign}) {substr $name,0,1,'s'};
  if($O{str}) {$name.='_str'};

  if($O{addr}) {

    my $spec=$Indirection_Key->[$O{addr}-1];

    $name.="_$spec";

  };

# ---   *   ---   *   ---

  my $ind=$O{addr} || $O{str};

  my $type=$frame->{$name}=bless {

    name=>$name,
    size=>($ind) ? 8 : $size,
    elem_count=>$count,

    fields=>$fields,
    subtypes=>$subtypes,

    sigil=>$sigil,

    %O,

  },$class;

  return $type;

};

# ---   *   ---   *   ---

sub is_str($self) {
  return $self->{name}=~ m[$STRTYPE_RE];

};

# ---   *   ---   *   ---
# get format for struct pack/unpack
# from the sizes of it's fields

sub packing_fmat(@sizes) {

  my $fmat=$NULLSTR;

  map {

    my $c=$PACK_SIZES->{$ARG*8};

    $fmat.=$c;
    $fmat.='<' if $c ne 'C';

  } @sizes;

  return $fmat;

};

# ---   *   ---   *   ---
# turns hash into bytes array

sub encode($self,%data) {

  my $out=$NULLSTR;

  my $fields=$self->{fields};
  my $subtypes=$self->{subtypes};

# ---   *   ---   *   ---
# struct

  if(@$fields) {

    my @sizes=array_keys($fields);
    my @names=array_values($fields);

    my @types=array_keys($subtypes);
    my @arrays=array_values($subtypes);

    @names=grep {!($ARG=~ m[\+\d+])} @names;

    my @data=map {$data{$ARG}} @names;
    map {$ARG="\x{00}" if !defined $ARG} @data;

# ---   *   ---   *   ---
# make key=>value pairs from unpacked data

    while(@data) {

      my $value_t=shift @types;
      my $array_sz=shift @arrays;

# ---   *   ---   *   ---

      my @slice=(shift @data);
      my @arsz=@sizes[0..$array_sz-1];

      if($Table->{$value_t}->is_str()) {

        my $char_sz=$Table->{$value_t}->{size};

        @slice=lmord(

          $slice[0],

          width=>$char_sz,
          elem_sz=>$char_sz,
          rev=>0,

        );

        my $diff=$array_sz-int(@slice);
        push @slice,(0)x$diff;

        @arsz=($char_sz) x int(@slice);

      } elsif(!($slice[0]=~ m/^\d+/)) {
        $slice[0]=ord($slice[0]);

      };

      my $fmat=packing_fmat(@arsz);
      $out.=pack $fmat,@slice;

      # as buffer
      if($array_sz>1) {
        @sizes=@sizes[$array_sz..$#sizes];

      # as single value
      } else {
        shift @sizes;

      };

    };

# ---   *   ---   *   ---
# primitive

  } else {

    my $fmat=packing_fmat($self->{size});
    $out.=pack $fmat,values %data;

  };

  return $out;

};

# ---   *   ---   *   ---
# gives back [key=>value] from bytes

sub decode($self,$data) {

  my $out=[];

  my $fields=$self->{fields};
  my $subtypes=$self->{subtypes};

# ---   *   ---   *   ---
# struct

  if(@$fields) {

    my @sizes=array_keys($fields);
    my @names=array_values($fields);

    my @types=array_keys($subtypes);
    my @arrays=array_values($subtypes);

    my $fmat=packing_fmat(@sizes);

    # grab the slice of memory and unpack
    my @values=unpack $fmat,$data;

# ---   *   ---   *   ---
# make key=>value pairs from unpacked data

    while(@names && @values) {

      my $value_t=shift @types;
      my $array_sz=shift @arrays;

      my $value;
      my $name;

# ---   *   ---   *   ---
# as buffer

      if($array_sz>1) {

        $value=[@values[0..$array_sz-1]];
        $name=$names[0];

        # cat string and remove nullbytes
        if($Table->{$value_t}->is_str()) {
          $value=mchr($value);
          $value=~ s[\x00+][]sg;

        };

        @values=@values[$array_sz..$#values];
        @names=@names[$array_sz..$#names];

# ---   *   ---   *   ---
# as single value

      } else {
        $value=shift @values;
        $name=shift @names;

      };

# ---   *   ---   *   ---
# append

      push @$out,$name=>$value;

    };

# ---   *   ---   *   ---
# primitive

  } else {

    my $fmat=packing_fmat($self->{size});

    my $value=unpack $fmat,$data;
    $out=[$self->{name}=>$value];

  };

  return $out;

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
# generate string types

    if($key=~ m[(?: byte|wide)]x) {
      $F->nit($key,$value,str=>1);

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
