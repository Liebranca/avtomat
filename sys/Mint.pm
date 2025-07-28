#!/usr/bin/perl
# ---   *   ---   *   ---
# MINT
# Makes coins ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Mint;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Chk;
  use Cask;

  use Type;
  use Bpack;

  use Warnme;
  use Fmat;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::IO;
  use Arstd::PM;

  use parent 'St';


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(image mount);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.9a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

St::vconst {


  # expr for fetching *expandable* reference type
  ref_t  => qr{^[^=]* (?: \=? (HASH|ARRAY))}x,

  # expr for spotting frozen coderefs
  sub_re => qr{^(\\&|\\X)},

  # expr for spotting internal references
  ptr_re => sub {

    my $s=$_[0]->PTR;
       $s="\Q$s";

    return qr{^$s(\d+)};

  },


  # primitives used by encoder
  enc_prims => [qw(

    cstr plstr

    tiny short mean  long
    byte word  dword qword

  )],


  # sequence terminator dummy
  EOS => sub {St::cpkg . '-EOS'},

  # reference marker
  PTR => sub {St::cpkg . '-PTR'},

  # file signature
  SIG => sub {
    my $have=bpack 'dword',0x24C0509E;
    return $have->{ct};

  },

};


# ---   *   ---   *   ---
# fetch or generate store F

sub set_storing($user_fn) {

  if(defined $user_fn) {

    return sub(@args) {

      $args[1]=defstore(@args[0..1]);
      $args[1]=$user_fn->(@args);

      return $args[1];

    };

  } else {
    return \&defstore;

  };

};


# ---   *   ---   *   ---
# ^same for load

sub set_loading($user_fn) {

  if(defined $user_fn) {

    return sub(@args) {

      $args[1]=$user_fn->(@args);
      $args[1]=defload(@args[0..1]);

      return $args[1];

    };

  } else {
    return \&defload;

  };

};


# ---   *   ---   *   ---
# cstruc

sub new($class,$src,%O) {


  # defaults
  $O{fn}      //= [];
  $O{args}    //= [];


  # passed value is object or path?
  my $mode=is_filepath "$src.gz";

  # ^set F to use accordingly
  my $user_fn = $O{fn}->[$mode];
  my $fn      = ($mode)
    ? set_loading $user_fn
    : set_storing $user_fn
    ;


  # make ice
  my $self=bless {

    walked => {},
    Q      => [],

    fn     => $fn,
    args   => $O{args},

    obj    => undef,
    mode   => ($mode) ? 'unmint' : 'mint' ,

    head   => undef,
    path   => [],
    out    => {},

    hist   => [],
    data   => undef,

    uid    => 0,

  },$class;


  # get object and give
  $self->{obj}=($mode)
    ? $self->from_bin($src)
    : $src
    ;

  return $self;

};


# ---   *   ---   *   ---
# decide if value must be expanded

sub register($self,$key,$vref) {


  # get value present in cache
  my $data         = $self->{data};
  my ($have,$idex) = $data->cgive($vref);

  # add descriptor to history
  my $path=$self->{path};
  push @$path,$key if length $key;

  my $out={

    type => $self->get_type($vref),

    path => [@$path],
    idex => $idex,

    vref => $vref,

  };

  push @{$self->{hist}},$out;

  # inform caller if we have a new value!
  return (! $have) ? $out : undef ;

};


# ---   *   ---   *   ---
# consume value from Q

sub get_next($self) {

  # consume next pair
  my $Q=$self->{Q};
  my($key,$vref)=(shift @$Q,shift @$Q);

  $vref //= null;


  # give non-null if expansion required
  return $self->register($key=>$vref);

};


# ---   *   ---   *   ---
# obtain encoding data about
# this value

sub get_type($self,$vref) {


  # get ctx
  my $mode   = $self->{mode};
  my $refn   = ref $vref;

  my ($type) = $vref =~ $self->ref_t;


  # reference can encode itself?
  my $blessed = is_blessref $vref;
  my $novex   = (
      ($blessed && $refn->can($mode))
  ||! defined $type

  );


  # ^inform caller!
  return ($novex)
    ? [$refn,null]
    : [$refn,$type]
    ;

};


# ---   *   ---   *   ---
# inspect value
#
# if it contains other values,
# expand it and pass them through an F
#
# returns the processed values!

sub proc_elem($self) {


  # find or stop
  my $head=$self->get_next();
  return $self->EOS if ! defined $head;


  # get ctx
  my $mode = $self->{mode};
  my $type = $head->{type};

  $self->{head} = $head;


  # have minting method?
  my @have=(

     length $type->[0]
  && $type->[0]->can($mode)

  ) ? $head->{vref}->$mode()
    : $self->vex()
    ;


  # give recurse path plus end marker
  return @have,$self->EOS;

};


# ---   *   ---   *   ---
# apply F to each value
# then give result

sub vex($self) {


  # get ctx
  my $head = $self->{head};
  my $data = $self->{data};
  my $vref = $head->{vref};
  my $fn   = $self->{fn};
  my $args = $self->{args};

  # map array to hash?
  my $type = $head->{type}->[1];
  my $src  = ($type eq 'ARRAY')
    ? array_key_idex $vref,1
    : $vref
    ;


  # skip if value needs no expansion!
  return ()

  if (! is_hashref $src)
  && (defined $type && $type ne 'HASH');


  # walk struc and give
  my @have=map {


    # filter out null and repeats
    my $defd=defined $src->{$ARG};
    my $have=($defd)
      ? $data->has($src->{$ARG})
      : undef
      ;

    # apply F to new && non-null
    my $value;

    if($defd &&! defined $have) {
      $value=$fn->($self,$src->{$ARG},@$args)

    } elsif(defined $have) {
      $value=$self->PTR . $have;

    } else {
      $value=undef;

    };

    $ARG=>$value;

  } keys %$src;

  return @have;

};


# ---   *   ---   *   ---
# apply F to nested structure

sub proc($self) {


  # reset ctx
  $self->{Q}    = [q[]=>$self->{obj}];
  $self->{data} = Cask->new();

  $self->{path} = [];
  $self->{hist} = [];

  # ^shorthands
  my $Q    = $self->{Q};
  my $path = $self->{path};


  # walk
  while(@$Q) {


    # handle path change
    if($Q->[0] && $Q->[0] eq $self->EOS) {

      pop   @$path;
      shift @$Q;

      next;

    };


    # expand next element
    unshift @$Q,$self->proc_elem;

  };

  return $self->{obj};

};


# ---   *   ---   *   ---
# walks the history struc to
# build the final binary

sub to_bin($self,$path) {


  # put file signature
  my $out=$self->SIG;

  # get ctx
  my @hist=reverse @{$self->{hist}};
  my $data=$self->{data};


  # get number of types used by elems
  my $order   = [@{$self->enc_prims}];

  my $typetab = array_key_idex $order;
  my $primcnt = int @$order;

  map {

    my @have     = @{$ARG->{type}};
    my $key      = join ',',@have;

    $ARG->{type} = $key;

    map {

      if(! exists $typetab->{$ARG}) {
        $typetab->{$ARG}=int @$order;
        push @$order,$ARG;

      };

    } @have,$key;


  } @hist;


  # get type/value/elem count
  my $typecnt = int(@$order) - $primcnt;
  my $datacnt = int(@$data) >> 1;
  my $elemcnt = int @hist;


  # get bytes required for header
  my ($size_t) = typeof bytesize $typecnt;
  my ($data_t) = typeof bytesize $datacnt;
  my ($elem_t) = typeof bytesize $elemcnt;

  ($size_t,$data_t,$elem_t)=(
    typefet($size_t),
    typefet($data_t),
    typefet($elem_t),

  );


  # ^put header!
  my $head=bpack 'byte,byte,byte'=>(
    $size_t->{sizep2},
    $data_t->{sizep2},
    $elem_t->{sizep2},

  );

  $out .= $head->{ct};


  # ^add type table
  $head  = bpack $size_t,$typecnt;
  $out  .= $head->{ct};

  $head  = bpack cstr=>@{$order}[
    $primcnt..int @$order-1

  ];

  $out  .= $head->{ct};


  # add value table size
  $head  = bpack $data_t=>$datacnt;
  $out  .= $head->{ct};


  # ^encode values
  my $ptr_re=$self->ptr_re;
  map {


    # unpack
    my $value = $data->[($ARG << 1) + 1];
    my $refn  = ref $value;


    # edge-case: bytearray!
    if(

       ($value=~ qr"\x{00}")
    || $refn eq 'Regexp'

    ) {

      $refn  = 'plstr';
      $value = $value;


    # edge case: internal pointers
    } elsif($value=~ s[$ptr_re][$1]) {
      $refn=Type->ptr_by_size($value);

    # edge-case: strings and numbers
    } elsif(! length $refn) {


      # have number?
      if($value=~ $NUM_RE) {
        ($refn) = typeof bytesize $value;

      # have good C string! ;>
      } else {
        $refn='cstr';

      };

    };

    my $type  = $typetab->{$refn};
    my $valid = (

      ! Type->is_base_ptr($refn)
    &&! Type->is_str($refn)

    &&! Type->is_valid($refn)

    );


    #  just a dummy, safely ignored
    if($valid) {

      my $have  = bpack $size_t=>$type;
         $out  .= $have->{ct};


    # write value to table
    } else {

      my $have = bpack "$size_t->{name},$refn"=>(
        $type,$value

      );

      $out .= $have->{ct};

    };


  } 0..$datacnt-1;


  # add elem table si<ze
  $head  = bpack $elem_t,$elemcnt;
  $out  .= $head->{ct};


  # make elem entry structure
  my $struc=join ',',(

    $size_t->{name},
    $data_t->{name},

    'cstr'

  );


  # encode elements
  map {

    my $path = join ' ',@{$ARG->{path}};
    my $type = $typetab->{$ARG->{type}};
    my $idex = $ARG->{idex};

    my $have = bpack $struc=>(
      $type,$idex,$path

    );

    $out .= $have->{ct};

  } @hist;


  # dump to disk and give
  owc $path=>$out;

  my @call=(gzip=>'-f'=>$path);
  system {$call[0]} @call;

  return;

};


# ---   *   ---   *   ---
# ^undo

sub from_bin($self,$path) {


  # open file
  my @call=(gunzip=>'-k'=>$path);
  system {$call[0]} @call;
  my $src=orc $path;

  unlink $path;

  # signature check
  my $sig  = $self->SIG;
  my $have = substr $src,0,length $sig,null;

  return throw_sig($have) if $have ne $sig;


  # get type/value/elem count
  $have=bunpacksu byte=>\$src,0,3;
  $have=$have->{ct};

  my ($size_t) = typeof 1 << $have->[0];
  my ($data_t) = typeof 1 << $have->[1];
  my ($elem_t) = typeof 1 << $have->[2];


  # read type table
  my $typecnt = bunpacksu $size_t=>\$src;
     $typecnt = $typecnt->{ct}->[0];

  $have = bunpacksu cstr=>\$src,0,$typecnt;
  $have = $have->{ct};


  # ^add prims
  my $order=[

    @{$self->enc_prims},
    map {$ARG=null if $ARG eq 0;$ARG

  } @$have];

  my $typetab=array_key_idex $order;


  # read value table size
  my $datacnt = bunpacksu $data_t=>\$src;
     $datacnt = $datacnt->{ct}->[0];

  my $data    = [];


  # decode values
  map {


    my $idex  = bunpacksu $size_t=>\$src;
       $idex  = $idex->{ct}->[0];


    my $type  = $order->[$idex];
    my $valid = Type->is_valid($type);

    my $pre   = null;
    my $fmat  = null;


    # have pointer?
    if(Type->is_base_ptr($type)) {
      $pre  = $self->PTR;
      $fmat = $type;

    # have dummy?
    } elsif(! $valid) {
      $pre=$type;

    # have primitive!
    } else {
      $fmat=$type;

    };


    my $value=null;

    if(length $fmat) {
      $value=bunpacksu $fmat=>\$src;
      $value=$value->{ct}->[0];

    };

    push @$data,$pre . $value;

  } 0..$datacnt-1;


  # read elem table size
  my $elemcnt = bunpacksu $elem_t=>\$src;
     $elemcnt = $elemcnt->{ct}->[0];

  # make elem entry structure
  my $struc=join ',',(

    $size_t,
    $data_t,

    'cstr'

  );


  my $struc_sz=
    sizeof($size_t)
  + sizeof($data_t)

  + 1;


  # decode elements...
  my $obj    = {};

  my $fn     = $self->{fn};
  my $args   = $self->{args};

  my $ptr_re = $self->ptr_re;

  my @blessf = ();


  # ^ensure all pointers are deref'd
  my @reftab=map {

    my ($idex,$href,$path)=@$ARG;

    $$href=$data->[$idex]

    if ! defined $$href
    || $$href ne $data->[$idex];

    if($$href) {

      $$href=[] if $$href eq 'ARRAY';
      $$href={} if $$href eq 'HASH';

      $data->[$idex]=$$href
      if ! is_scalarref $data->[$idex];

    };

    [$path,$idex];


  # ^but first unpack ;>
  } map {

    my $have=bunpacksu $struc=>\$src,0,3;
       $have=$have->{ct};

    my ($type,$value,@path)=@$have;

    my $idex  = $value;
    my $isptr = undef;

    $type  = $order->[$type];
    $value = $data->[$idex];

    @path  = split $SPACE_RE,($path[0] eq 0)
      ? 'ROOT' : $path[0] ;


    # handle internal pointer
    if(

       defined $value
    && $value=~ s[$ptr_re][$1]

    ) {

      $isptr = $idex;

      $idex  = $value;
      $value = $data->[$value];


    };

    $value=$fn->($self,$value,@$args);


    # write to dst
    my $nobj      = $obj;
    my $href      = \$nobj;
    my $href_path = [];

    while(@path && $path[0] ne 'ROOT') {

      my $key = shift @path;
      push @$href_path,$key;

      $key = '_0' if ! $key;

      $href    = \$$href->{$key};
      $$href //= {} if @path;

    };


    # assign scalar
    if(! defined $$href) {
      $$href=$value;


    # convert hash to array
    } elsif(

       defined $value
    && $value eq 'ARRAY'

    ) {

      $$href=[map {
        my $idex=(! $ARG) ? "_$ARG" : "$ARG";
        $$href->{$idex};

      } 0..int(keys %{$$href})-1];


    # handle blessed ones
    } elsif(
       defined $value
    && $value ne 'HASH'

    ) {
      push @blessf,[$value,$href_path,$idex];

    };


    # overwrite placeholders in cache
    my $repl=(
       $value eq 'HASH'
    && $data->[$idex] ne $$href

    );


    if(defined $isptr) {
      $data->[$isptr]=\$data->[$idex];
      [$isptr,$href,$href_path];

    } else {
      $data->[$idex]=$$href;
      [$idex,$href,$href_path];

    };


  } 0..$elemcnt-1;


  # conditionally load classes
  cloadi map {$ARG->[0]} @blessf;

  # generate blessed objects
  map {

    my ($class,$path,$idex)=@$ARG;

    my $have = $data->[$idex];
    my $ice  = $have;


    # need to run decode method?
    if(! is_blessref($have)) {

      $ice=($class->can('unmint'))
        ? $class->unmint($have)
        : bless $have,$class
        ;

      $data->[$idex]=$ice;

    };


    # get value within out struc
    my $nobj=$obj;
    my $href=\$nobj;

    map {

      if(is_arrayref($$href)
      || $$href=~ qr{=ARRAY}) {
        $href=\$$href->[$ARG];

      } elsif(defined $$href) {
        $href=\$$href->{$ARG};

      };


    } @$path;


    # ^overwrite
    $$href=$ice if ! is_scalarref $ice;


  } @blessf;


  # revaluate final instance
  my @post=map {

    my ($path,$idex)=@$ARG;

    my $nobj=$obj;
    my $href=(@$path) ? \$nobj : \$obj ;
    my $prev=undef;


    # get the path again...
    map {

      $prev=$href;

      if(

         defined $$href

      && (is_arrayref($$href)
      || $$href=~ qr{=ARRAY})

      ) {

        $ARG=~ $NUM_RE
        or (fatdump $prev,blessed=>1),

        errout 'faulty ARRAY unminting',
        lvl=>$AR_FATAL;

        $href=\$$href->[$ARG]


      } elsif(
         defined $$href
      && $$href=~ qr{=?HASH}

      ) {

        $href=\$$href->{$ARG};

      };

    } @$path;


    # fetch value again...
    $$href=(is_scalarref $data->[$idex])
      ? ${$data->[$idex]}
      : $data->[$idex]
      ;


    # have post-decode hook?
    (  is_blessref($$href)
    && $$href->can('REBORN')

    ) ? ($$href)
      : ()
      ;

  } @reftab;


  # run hooks and give
  array_dupop \@post;
  map {$ARG->REBORN} reverse @post;


  return $obj;

};


# ---   *   ---   *   ---
# errmes

sub throw_sig($have) {

  $have=join '',(
    map {sprintf "%02X",$ARG}
    unpack 'C*',$have

  );

  Warnme::invalid 'Mint signature',

  obj  => $have,
  give => null;

};

sub warn_dir($path) {

  warnproc "directory passed as file: '%s'",

  args => [$path],
  give => null;

};


# ---   *   ---   *   ---
# applies processing to object
# before storing it

sub image($path,$obj,%O) {

  return warn_dir $path
  if -d $path;


  my $class = St::cpkg;
  my $self  = $class->new($obj,%O);

  $self->proc();
  St::PENDING;

  $self->to_bin($path);

  return $path;

};


# ---   *   ---   *   ---
# ^undo

sub mount($path,%O) {

  my $class = St::cpkg;
  my $self  = $class->new($path,%O);

  return $self->{obj};

};


# ---   *   ---   *   ---
# default methods for load/store
#
# if you define your own methods,
# these will still be applied to
# ensure all values can be stored!

sub defstore($self,$vref) {

  return (is_coderef $vref)
    ? codefreeze($vref)
    : $vref
    ;

};

sub defload($self,$vref) {

  my $re=$self->sub_re;

  return (defined $vref && $vref=~ s[$re][])
    ? codethaw($vref,$1)
    : $vref
    ;

};


# ---   *   ---   *   ---
# freeze code references in
# object to store it
#
# * named coderef to name
# * anon to source

sub codefreeze($fn) {

  my $name='\&' . codename $fn,1;

  return ($name=~ qr{__ANON__$})

    ? '\X' . $name . '$;'
    . $St::Deparse->coderef2text($fn)

    : $name

    ;

};


# ---   *   ---   *   ---
# ^undo

sub codethaw($fn,$type) {


  # fetch named reference?
  if($type eq '\&') {
    cloads $fn;
    return \&$fn;


  # regenerate anonymous!
  } else {


    # cleanup value and get package
    my ($name,$body)=split '\$;',$fn;
    $name=substr $name,2,(length $name)-2;

    my ($pkg)   = cloads $name;
    $pkg      //= 'main';


    # set scope and define the F
    my $wf=eval "package $pkg;sub $body";

    # ^or die if regen fails ;>
    if(! defined $wf) {

      say "BAD CODEREF\n\n","sub $name $body";
      exit -1;

    };

    return $wf;

  };

};


# ---   *   ---   *   ---
1; # ret
