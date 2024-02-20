#!/usr/bin/perl
# ---   *   ---   *   ---
# FSTRUC
# File/block structures
# used for binary dumps
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package FStruc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_words);

  use List::Util qw(sum);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Bpack;
  use Chk;

  use Bitformat;

  use Arstd::Array;
  use Arstd::String;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $HEADKEY=>'__fstruc_head';

# ---   *   ---   *   ---
# cstruc

sub new($class,@order) {

  # static patterns
  state $head_re   = qr{\s*\*\s*\[(.+)\]};
  state $rehead_re = qr{^\^};


  # array as hash
  my $idex   = 0;
  my @keys   = array_keys(\@order);
  my @values = array_values(\@order);

  # build header
  my @head_keys = ();
  my @head_fmat = ();
  my $rehead    = {};

  # header read/reuse filter
  my $rehead_chk = sub ($cntsz,$idex) {

    if($cntsz=~ s[$rehead_re][]) {
      $rehead->{$keys[$idex]}=$cntsz;

    } else {
      push @head_keys,$keys[$idex];
      push @head_fmat,$cntsz;

    };

  };


  # apply filter to struc format
  @values=map {

    my ($fmat,$cntsz)=@$ARG;

    # have counter?
    $rehead_chk->($cntsz,$idex)
    if defined $cntsz;

    $ARG=$fmat;

    # go next and give
    $idex++;
    $ARG;

  } @values;


  # ^have any header data?
  if(@head_fmat) {
    my $fmat=join ',',@head_fmat;
    unshift @head_keys,$fmat;

  };


  # get value=>(rel fptr)
  my @procs=map {

    (Bitformat->is_valid($ARG))
  | ($class->is_valid($ARG) << 1)
  ;

  } @values;


  # get fields that are themselves
  # instances of this class
  my $substruc = {};
     $idex     = 0;

  map {

    $substruc->{$ARG}=$values[$idex]
    if $procs[$idex] & 0x2;

    $idex++;

  } @keys;


  # make ice
  my $self=bless {

    #   size fields to read
    # / size fields to reuse
    head    => \@head_keys,
    rehead  => $rehead,

    # the actual fields
    fmat    => \@values,
    proc    => \@procs,

    # used for walking
    order    => \@keys,
    substruc => $substruc,

  },$class;


  return $self;

};

# ---   *   ---   *   ---
# makes ordered array from
# data hashref

sub ordered($self,$data) {

  return [map {
    $ARG=>$data->{$ARG};

  } $HEADKEY,@{$self->{order}}];

};

# ---   *   ---   *   ---
# calc elem offsets from
# the result of from_bytes

sub labels($self,$b,$name='',$base=0x00) {


  # are we derived? ;>
  my $class  = ref $self;
     $name  .= '.' if length $name;

  # get sorted key list
  my $order = $self->ordered($b->{ct});
  my @order = array_keys($order);


  # ^walk
  my $ptr  = $base;
  my $idex = 0;

  return map {

    # fetch element size
    my $key    = $ARG;
    my $full   = "$name$key";

    my $size   = $b->{ezy}->{$key};
       $size //= 0;

    # get start and go next
    my $beg   = $ptr;
       $ptr  += $size;

    # give [elem => begof,sizeof]
    my @out=($full => [$beg,$size]);


    # need to recurse?
    if($key ne $HEADKEY) {

      my $fmat=$self->{fmat}->[$idex++];

      if($class->is_valid($fmat)) {
        my $o    = $b->{ct}->{$key};
        my @deep = $fmat->labels($o,$full,$beg);

        push @out,@deep;

      };

    };

    @out;
  } @order;

};

# ---   *   ---   *   ---
# flattens the result of
# from_bytes
#
# careful! you can't get
# a complete label array
# from this!

sub flatten($self,$b) {

  # are we derived? ;>
  my $class  = ref $self;

  # get sorted key list
  my $order = $self->ordered($b->{ct});
  my @order = array_keys($order);

  # ^walk
  my $idex=0;
  return { map {

    my $key=$ARG;
    if($key ne $HEADKEY) {

      # need to recurse?
      my $fmat=$self->{fmat}->[$idex++];
      if($class->is_valid($fmat)) {

        my @list = @{$b->{ct}->{$key}};
        my $jdex = 0;

        map {

          my $skey=(@list > 1)
            ? "$key\[$jdex]"
            : $key
            ;

          $jdex++;
          $skey=>$fmat->flatten($ARG)

        } @list;


      # ^nope, plain elem
      } else {
        $key=>$b->{ct}->{$key}->{ct};

      };

    } else {()};

  } @order };

};

# ---   *   ---   *   ---
# fills out undefined values

sub complete($self,$dst) {

  my $class = ref $self;
  my $idex  = 0;

  map {

    my $key  = $ARG;
    my $fmat = $self->{fmat}->[$idex++];


    # value missing?
    if(! exists $dst->{$key}) {

      # need recurse?
      if($class->is_valid($fmat)) {

        my $inner={};

        $fmat->complete($inner);
        $dst->{$key}=[$inner];

      # ^nope, add plain array
      } else {
        my $cnt=int split $COMMA_RE,$fmat;
        $dst->{$key}=[(0x00) x $cnt];

      };


    # incomplete primitive?
    } elsif(! $class->is_valid($fmat)) {

      my $cnt  = int split $COMMA_RE,$fmat;
      my $diff = int @{$dst->{$key}} % $cnt;

      push @{$dst->{$key}},(0x00) x $diff;


    # ^incomplete sub-struc?
    } else {

      map {
        $fmat->complete($ARG)

      } @{$dst->{$key}};

    };


  } @{$self->{order}};


  return;

};

# ---   *   ---   *   ---
# proto: run F with elem,
# accto elem type

sub _proc_elem($self,$farray,$e,$idex) {

  # get ctx vars
  $e->{key}  = $self->{order}->[$idex];
  $e->{fmat} = $self->{fmat}->[$idex];

  # get func to run
  my $f=$self->{proc}->[$idex];
     $f=$farray->[$f];

  # ^exec
  return $self->$f($e);

};

# ---   *   ---   *   ---
# collapse elem size hash

sub _up_ezycol($e) {

  my $len = 0;
  my @Q   = values %{$e->{ezy}};

  while(@Q) {

    my $i=shift @Q;

    if(is_hashref($i)) {
      push @Q,values %$i;

    } else {
      $len+=$i;

    };

  };


  return $len;

};

# ---   *   ---   *   ---
# read from bytestr

sub from_bytes($self,$rawref,%O) {

  # self->proc[X] is idex to one of
  # these functions
  state $farray=[
    '_unpack_prims',
    '_unpack_bitformat',
    '_unpack_struc',

  ];

  # defaults
  $O{ptr}  //= 0;
  $O{base} //= $NULLSTR;

  # ^handle namespace
  $O{base}  .= '.' if length $O{base};


  # bind ctx
  my $e={

    key    => $NULLSTR,
    fmat   => $NULLSTR,

    src    => $rawref,

    cnt    => {},
    ezy    => {},


    ptr    => $O{ptr},
    base   => $O{base},
    labels => [],

  };


  # read header
  my $b    = {ct=>[],len=>0};
  my @head = @{$self->{head}};

  if(@head) {
    $b = bunpacksu $head[0],$e->{src};
    $e->{ezy}->{$HEADKEY} = $b->{len};

    push @{$e->{labels}},
       "$e->{base}$HEADKEY"
    => [$e->{ptr},$b->{len}]
    ;

    $e->{ptr} += $b->{len};

  };


  # ^get read sizes
  map {
    $e->{cnt}->{$ARG}
  = shift @{$b->{ct}}

  } @head[1..$#head];

  # ^get reused sizes
  map {
    $e->{cnt}->{$ARG}
  = $e->{cnt}{$self->{rehead}->{$ARG}}

  } keys %{$self->{rehead}};


  # walk elems
  my $idex=0;

  my $out={ map {
     $e->{key}
  => $self->_proc_elem($farray,$e,$idex++),

  } @{$self->{order}} };


  # ^collapse
  return {

    labels  => $e->{labels},
    ezy     => $e->{ezy},

    ct      => $out,
    len     => _up_ezycol $e,

  };

};

# ---   *   ---   *   ---
# ^consume bytes

sub from_strm($self,$sref,$pos,%O) {

  $O{ptr} //= $pos;

  my $rawref=\(substr $$sref,
    $pos,(length $$sref) - $pos

  );

  return $self->from_bytes($rawref,%O);

};

# ---   *   ---   *   ---
# get element count for
# unpacking subroutines

sub _u_get_elem_cnt($e) {

  my $cnt=1;

  if(exists $e->{cnt}->{$e->{key}}) {

    $cnt   = $e->{cnt}->{$e->{key}};
    $cnt //= 1;

    if(! is_hashref($e->{fmat})) {
      my $mul=int split $COMMA_RE,$e->{fmat};
      $cnt *= $mul;

    };

  };

  return $cnt;

};

# ---   *   ---   *   ---
# write meta and give unpacked

sub _u_cat($e,$b) {

  # add label
  push @{$e->{labels}},
     "$e->{base}$e->{key}"
  => [$e->{ptr},$b->{len}]
  ;

  # record length
  $e->{ezy}->{$e->{key}}=$b->{len};
  $e->{ptr}+=$b->{len};


  return $b;

};

# ---   *   ---   *   ---
# ^prim guts

sub _unpack_prims($self,$e) {
  my $cnt=_u_get_elem_cnt($e);
  _u_cat $e,bunpacksu $e->{fmat},$e->{src},0,$cnt;

};

# ---   *   ---   *   ---
# ^bitformat guts

sub _unpack_bitformat($self,$e) {
  my $cnt=_u_get_elem_cnt($e);
  _u_cat $e,$e->{fmat}->from_strm($e->{src},0,$cnt);

};

# ---   *   ---   *   ---
# ^recurse guts

sub _unpack_struc($self,$e) {

  my $class = ref $self;
  my $cnt   = _u_get_elem_cnt($e);

  return [map {


    # get namespace
    my $key  = $e->{key};
    my $base = $e->{base};

    # ^have array?
    $key .= "[$ARG]" if $cnt > 1;


    # read bytestr
    my $b=$e->{fmat}->from_strm(

      $e->{src},0,

      ptr  => $e->{ptr},
      base => "$base$key"

    );


    # add labels
    push @{$e->{labels}},
       "$base$key"
    => [$e->{ptr},$b->{len}]
    ;

    push @{$e->{labels}},@{$b->{labels}};


    # go next
    $e->{ezy}->{$key}=$b->{len};
    $e->{ptr}+=$b->{len};

    $b;

  } 0..$cnt-1];

};

# ---   *   ---   *   ---
# write to buff

sub to_bytes($self,%data) {

  # self->proc[X] is idex to one of
  # these functions
  state $farray=[
    '_pack_prims',
    '_pack_bitformat',
    '_pack_struc'

  ];

  # defaults
  $data{-ptr}  //= 0;
  $data{-base} //= $NULLSTR;

  # ^handle namespace
  $data{-base}  .= '.' if length $data{-base};


  # bind ctx
  my $e={

    key    => $NULLSTR,
    fmat   => $NULLSTR,

    src    => \%data,
    dst    => $NULLSTR,

    cnt    => {},
    ezy    => {},


    ptr    => $data{-ptr},
    base   => $data{-base},
    labels => [],

  };


  # load header keys
  my @keys=@{$self->{head}};
  shift @keys;

  # ^pass to counter
  $e->{cnt}={map {$ARG=>0} @keys};


  # walk elems
  my $idex=0;

  map {
    $self->_proc_elem($farray,$e,$idex++)

  } @{$self->{order}};


  # get ordered counters
  my @cnt=map {$e->{cnt}->{$ARG}} @keys;


  # ^pre-pend counters as header
  if(@{$self->{head}}) {

    my $b=bpack $self->{head}->[0] => @cnt;

    # ^cat to final
    $e->{ezy}->{$HEADKEY} = $b->{len};
    $e->{dst} = catar $b->{ct},$e->{dst};

    # ^adjust previous labels!
    array_vmap $e->{labels},sub ($vref) {
      ($$vref)->[0] += $b->{len};

    };

    # ^make label for header
    my $key  = $HEADKEY;
    my $base = $e->{base};
    my $full = "$base$key";

    unshift @{$e->{labels}},
      $full=>[$data{-ptr},$b->{len}];

  };


  # ^collapse
  return {

    labels => $e->{labels},

    ct     => $e->{dst},
    len    => _up_ezycol $e,

  };

};

# ---   *   ---   *   ---
# ^inserts result in existing
# bytestr

sub to_strm($self,$sref,$pos,%data) {

  $data{-ptr} //= $pos;

  my $b=$self->to_bytes(%data);

  # you meant CAT, right?
  if($pos == length $$sref) {
    $$sref .= $b->{ct};

  # ^nope, insertion
  } else {
    substr $$sref,$pos,$b->{len},$b->{ct};

  };


  return $b;

};

# ---   *   ---   *   ---
# get element count and
# data for packing subroutines

sub _p_get_elems($e) {

  my @data = @{$e->{src}->{$e->{key}}};
  my $cnt  = int @data;

  if(exists $e->{cnt}->{$e->{key}}) {

    $cnt //= 1;

    if(! is_hashref($e->{fmat})) {

      my $mul=($cnt > 1)
        ? int split $COMMA_RE,$e->{fmat}
        : 1
        ;

      $cnt /= $mul;

    };

    $e->{cnt}->{$e->{key}}=$cnt;

  };

  return @data;

};

# ---   *   ---   *   ---
# cat packed to dst

sub _p_cat($e,$b) {

  # make label for elem
  my $key  = $e->{key};
  my $base = $e->{base};
  my $full = "$base$key";

  push @{$e->{labels}},
    $full=>[$e->{ptr},$b->{len}];

  # ^go next
  $e->{ptr} += $b->{len};


  # write bytes to out
  $e->{ezy}->{$key} = $b->{len};
  $e->{dst} .= catar $b->{ct};

};

# ---   *   ---   *   ---
# ^prim guts

sub _pack_prims($self,$e) {
  _p_cat $e,bpack $e->{fmat},_p_get_elems($e);

};

# ---   *   ---   *   ---
# ^Bitformat guts

sub _pack_bitformat($self,$e) {
  _p_cat $e,$e->{fmat}->to_bytes(_p_get_elems($e));

};

# ---   *   ---   *   ---
# ^recurse guts

sub _pack_struc($self,$e) {

  my @data=_p_get_elems($e);
  my $idex=0;

  map {

    # get namespace
    my $key  = $e->{key};
    my $base = $e->{base};

    # ^have array?
    $key .= "[$idex]" if @data > 1;

    # get packed bytestr
    my $b=$e->{fmat}->to_bytes(

      %$ARG,

      -ptr  => $e->{ptr},
      -base => "$base$key",

    );


    # add labels
    push @{$e->{labels}},
       "$base$key"
    => [$e->{ptr},$b->{len}]
    ;

    push @{$e->{labels}},@{$b->{labels}};


    # write to out and go next
    $e->{ezy}->{$key} = $b->{len};
    $e->{dst} .= catar $b->{ct};

    $idex++;
    $b;


  } @data;

};

# ---   *   ---   *   ---
1; # ret
