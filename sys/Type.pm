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

  use Carp;
  use Readonly;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::Hash;
  use Arstd::Re;

  use parent 'St';
  use Vault 'ARPATH';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    sizeof
    packof

    bpack
    bunpack

    array_typeof

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.03.8;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    -autoload=>[qw(

      pevec

    )],

   }};

  our $Indirection_Key=[qw(ptr pptr xptr)];

  Readonly our $PACK_SIZES=>hash_invert({

    'Q'=>64,
    'L'=>32,
    'S'=>16,
    'C'=>8,

  },duplicate=>1);


  # for matching widths
  Readonly our $EZY_LIST=>
    [qw(byte word dword qword)];

  Readonly our $PTR_LIST=>
    [qw(thin short wide long)];


  Readonly our $EZY_RE=>re_eiths($EZY_LIST);
  Readonly our $PTR_RE=>re_eiths($PTR_LIST);


  # make/load table
  our $Table=Vault::cached(

    'Table',\&gen_type_table,


    # paste (name) => 1 << N
    IDEXUP_P2(0,sub {$_[0]=>$_[1]},@$EZY_LIST),
    IDEXUP_P2(0,sub {$_[0]=>$_[1]},@$PTR_LIST),


    # measuring
    unit    =>   16,
    half    =>   32,
    line    =>   64,

    page    => 4096,


    # function types
    nihil   =>    8,
    stark   =>    8,
    signal  =>    8,

  );

# ---   *   ---   *   ---
# vector types
# i blame glsl ;>

sub pevec($class,$frame,$name) {

  state $re=qr{^
    (?<type> [A-Za-z]+)
    (?<size> \d+)

  $}x;

  ($name=~ $re) or goto ERR;

  my $type  = $+{type};
  my $size  = $+{size};

#  ! ($size % 4) or goto ERR;

  my @names=();

  if($size == 4) {
    @names=qw(x y z w);

  } else {

    my $i    = 0;
    my $cols = $size/4;

    @names = map {
      "$ARG" . int(($i++)/4)

    } (qw(x y z w) x $cols);

  };

  my $elems=[map {$type=>$ARG} @names];

# ---   *   ---   *   ---


OK:
  return $frame->new($name,$elems);


ERR:
  croak "$name is not a valid pevec";

};

# ---   *   ---   *   ---

  Readonly my $STRTYPE_RE=>qr{_str}x;
  Readonly my $PTRTYPE_RE=>qr{_ptr}x;

# ---   *   ---   *   ---
# get bytesize of type

sub sizeof($name) {

  state $re=qr{(pl)?cstr$ }x;
  return 1 if $name=~ $re;


  croak "$name not in peso typetab\n"
  if ! defined $Table->{$name};

  return $Table->{$name}->{size};

};

# ---   *   ---   *   ---
# ^get packing char for type ;>

sub packof($name) {

  my $tab={
    'cstr'   => 'Z',
    'plcstr' => '$Z',

  };

  return (! exists $tab->{$name})
    ? $PACK_SIZES->{sizeof($name)  << 3}
    : $tab->{$name}
    ;

};

# ---   *   ---   *   ---
# pack/unpack using peso types

sub _bpack_proto($f,$ezy,@data) {

  my @out   = ([]);
  my $total = 0;

  my @types = split $COMMA_RE,$ezy;


  # make sub ref
  $f = "_array$f";
  $f = \&$f;

  # ^call
  (@out)=$f->(
    \@types,@data

  );

  $total=pop @out;


  return (@out,$total);

};

# ---   *   ---   *   ---
# ^bat
#
# it *is* terrible
#
# however, this spares us having
# to duplicate two almost identical
# subroutines

sub _array_bpack_proto(

  $f,

  $types,
  $data,

  $iref,
  $tref,
  $oref

) {

  # get format chars
  my $fmat=packof($types->[$$iref]);

  # ^call F with format,data
  push @{$oref->[0]},$f->($fmat,$data);
  $oref->[$$iref+1]++;

  $$tref+=(exists $Table->{$types->[$$iref]})
    ? sizeof($types->[$$iref])
    : 1+length $oref->[0]->[-1]
    ;


  # go next, wrap-around types
  $$iref++;
  $$iref&=$$iref * ($$iref < @$types);

};

# ---   *   ---   *   ---
# ^packing guts

sub _bpack($fmat,@data) {
  ($fmat,@data)=_fmat_data_break(1,$fmat,@data);
  return pack $fmat,@data;

};

# ---   *   ---   *   ---
# ^bat

sub _array_bpack($types,@data) {

  my @out   = ([],map {0} 0..@$types-1);

  my $idex  = 0;
  my $total = 0;

  # get type of each elem,
  # then pack individual elems
  map { _array_bpack_proto(

    \&_bpack,

    $types,
    $ARG,

    \$idex,
    \$total,
    \@out,

  )} @data;


  return (@out,$total);

};

# ---   *   ---   *   ---
# plain iface wraps

sub bpack($ezy,@data) {
  return _bpack_proto('_bpack',$ezy,@data);

};

# ---   *   ---   *   ---
# unpacking guts

sub _bunpack($fmat,$buf) {
  ($fmat,$buf)=_fmat_data_break(0,$fmat,$buf);
  return unpack $fmat,$buf;

};

# ---   *   ---   *   ---
# ^bat

sub _array_bunpack($types,$buf,$cnt) {

  my @out   = ([],map {0} 0..@$types-1);

  my $idex  = 0;
  my $total = 0;

  # get type of each elem,
  # then pack individual elems
  map { _array_bpack_proto(

    \&_bunpack,

    $types,
    (substr $buf,$total,(length $buf)-$total),

    \$idex,
    \$total,
    \@out,

  )} 0..($cnt*int @$types)-1;


  return (@out,$total);

};

# ---   *   ---   *   ---
# ^iface wraps
# unpacks and consumes bpack'd

sub bunpack($ezy,$sref,$cnt) {

  my ($ct,@cnt)=_bpack_proto(
    '_bunpack',$ezy,$$sref,$cnt

  );

  my $total=$cnt[-1];
  substr $$sref,0,$total,$NULLSTR;


  return ($ct,@cnt);

};

# ---   *   ---   *   ---
# handle perl string to cstring
# and other edge-cases, maybe...

sub _fmat_data_break($packing,$fmat,@data) {

  Readonly my $re=>qr{\$Z};

  if($fmat=~ $re) {

    @data=map {(

      (map {ord($ARG)} split $NULLSTR,$ARG),
      0x00

    )} @data if $packing;

    $fmat=($packing) ? 'C*' : 'Z*';

  };

  return $fmat,@data;

};

# ---   *   ---   *   ---
# get type-list for bpack
# accto provided bytesize

sub array_typeof($size) {

  my @out=();

  map {

    my $ezy=sizeof($ARG);

    while ($size >= $ezy) {
      push @out,$ARG;
      $size-=$ezy;

    };

  } qw(qword dword word byte);


  return @out;

};

# ---   *   ---   *   ---
# cstruc

sub new(

  # implicit
  $class,$frame,

  # actual
  $name,
  $elems,

  # options
  %O

) {

  # defaults
  $O{real} //= 0;
  $O{sign} //= 0;
  $O{addr} //= 0;
  $O{str}  //= 0;


  my $size  = 0;
  my $count = 0;
  my $sigil = 0;

  my $SIGIL_FLAGS={

    q[sign] => 0x10,
    q[real] => 0x20,
    q[ptr]  => 0x40,
    q[str]  => 0x80,

  };

  my $fields   = [];
  my $subtypes = [];


  # struct:
  #
  # 'type_name'=>[
  #
  #   'type_name'=>'elem_name'
  #   ...
  #
  # ];

  if(length ref $elems) {

    $sigil |= 8 | $SIGIL_FLAGS->{ptr};

    while(@$elems) {

      my $elem_type=shift @$elems;
      my $elem_name=shift @$elems;

      my $elem_sz=$frame->{$elem_type}->{size};

      my @names=split $COMMA_RE,$elem_name;
      if(@names > 1) {goto MUL_NAMES};

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


  # primitive: [type_name=>size]
  } else {

    $count = 1;
    $size  = $elems;

    $sigil = $size

    | ($SIGIL_FLAGS->{sign} * $O{sign})
    | ($SIGIL_FLAGS->{real} * $O{real})

    | ($SIGIL_FLAGS->{ptr}  * $O{addr})
    | ($SIGIL_FLAGS->{str}  * $O{str} )

    ;

  };


  # ugly arse specifiers...
  if($O{sign}) {$name="s$name"};
  if($O{str}) {$name.='_str'};

  if($O{addr}) {

    my $spec=$Indirection_Key->[$O{addr}-1];

    $name.="_$spec";

  };



  my $ind  = $O{addr} || $O{str};

  my $type = $frame->{$name}=bless {

    name        => $name,
    size        => ($ind) ? 8 : $size,
    elem_count  => $count,

    fields      => $fields,
    subtypes    => $subtypes,

    sigil       => $sigil,

    %O,

  },$class;

  return $type;

};

# ---   *   ---   *   ---

sub is_str($self) {
  return $self->{name}=~ m[$STRTYPE_RE];

};

sub is_ptr($self) {
  return $self->{name}=~ m[$PTRTYPE_RE];

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

  my $out      = $NULLSTR;

  my $fields   = $self->{fields};
  my $subtypes = $self->{subtypes};

  # struct
  if(@$fields) {
    $out=$self->encode_struc(%data);

  # primitive
  } else {
    my $fmat=packing_fmat($self->{size});
    $out.=pack $fmat,values %data;

  };

  return $out;

};

# ---   *   ---   *   ---
# ^crux for brevity

sub encode_struc($self,%data) {

  state $array_re = qr{\+\d+$};
  state $num_re   = qr{^\d+};

  my $out      = $NULLSTR;

  my $fields   = $self->{fields};
  my $subtypes = $self->{subtypes};

  # unpack fields
  my @sizes  = array_keys($fields);
  my @names  = grep {
    ! ($ARG=~ $array_re)

  } array_values($fields);

  # unpack fields' types
  my @types  = array_keys($subtypes);
  my @arrays = array_values($subtypes);

  my @data   = map {(! defined $data{$ARG})
    ? "\x{00}"
    : $data{$ARG}
    ;

  } @names;

  # make key=>value pairs from unpacked data
  while(@data) {

    my $value_t  = shift @types;
    my $array_sz = shift @arrays;

    my @slice    = (shift @data);
    my @arsz     = @sizes[0..$array_sz-1];

    # string to bytes
    if($Table->{$value_t}->is_str()) {

      my $char_sz=$Table->{$value_t}->{size};

      @slice=lmord(

        $slice[0],

        width   => $char_sz,
        elem_sz => $char_sz,
        rev     => 0,

      );

      my $diff=$array_sz-int(@slice);
      push @slice,(0) x $diff;

      @arsz=($char_sz/8) x int(@slice);

    # ^single char
    } elsif(! ($slice[0]=~ $num_re)) {
      $slice[0]=ord($slice[0]);

    };

    my $fmat=packing_fmat(@arsz);
    $out.=pack $fmat,@slice;

    # as buffer
    if($array_sz > 1) {
      @sizes=@sizes[$array_sz..$#sizes];

    # as single value
    } else {
      shift @sizes;

    };

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

    my $t=$F->new($key,$value);

    if($fptr) {
      $t->{addr}=$indlvl;
      $t->{sign}=0;

    };


    # generate floating types
    if($key=~ m[(?: dword|qword)]x) {

      my $real_type=(
        'real','dreal'

      )[$key eq 'qword'];

      $F->new($real_type,$value,real=>1);
      $F->new(

        $real_type,$value,

        real=>1,
        addr=>$indlvl

      );

    };


    # generate string types
    if($key=~ m[(?: byte|word)]x) {
      $F->new($key,$value,str=>1);

    };


    # generate signed and pointers
    if($key=~ m[(?: byte|word|dword|qword)]x) {

      $F->new($key,$value,sign=>1);
      $F->new(

        $key,$value,

        sign=>0,
        addr=>$indlvl

      );

    };

  }}; # top loop


  # make vector types
  my @vectypes=qw(

    real2   real3   real4
    dword2  dword3  dword4
    sdword2 sdword3 sdword4

  );

  push @vectypes,'real16','real9';
  map {$F->pevec($ARG)} @vectypes;

  return $F;

};

# ---   *   ---   *   ---
1; # ret
