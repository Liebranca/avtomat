#!/usr/bin/perl
# ---   *   ---   *   ---
# TYPE:MAKE
# Galaxy spawner
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# TODO: at [*fetch]:
#
# * separate the code that procs
#   the ptr_t flags
#
# * make that into it's own F
#
# * use it to make ptr to type,
#   including strucs
#
#
# later on, generalize utype maker
# to make the struc method (over at Type)
# a bit more modular

# ---   *   ---   *   ---
# deps

package Type::MAKE;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_hashref is_null);

  use Arstd::Array qw(
    nkeys
    nvalues
    flatten
  );
  use Arstd::Hash qw(gvalues);
  use Arstd::Bytes qw(bitsize);
  use Arstd::String qw(cat strip gstrip gsplit);
  use Arstd::Token qw(tokenpop);
  use Arstd::Re qw(pekey);
  use Arstd::throw;

  use Tree::C;
  use St;


# ---   *   ---   *   ---
# adds to your namespace

  our @ISA=qw(Exporter);
  our @EXPORT_OK=qw(
    typename
    typetab
    typefet
    typedef

    struc
    union
    restruc

    badtype
    badptr
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM


# to get size as a power of 2...
sub _asis {$_[0]=>$_[1]};


# "Readonly" somehow managed to allow
# for these values to be overwritten
#
# so now we have to do it the hard way...

St::vconst {
  LIST => {
    # min to max size for all base types
    ezy=>[qw(
      byte  word  dword qword
      xword yword zword
    )],

    # ^real dword/real qword
    real=>[qw(
      real dreal
    )],

    # ^vector specs
    vec_t=>[qw(
      vec mat
    )],

    # valid *element* sizes for base types
    # ie what a vector can contain!
    prim=>[qw(
      byte word dword qword real dreal
    )],

    # ^ALL the elements!
    defn=>[qw(
      byte  word  dword qword
      xword yword zword

      real  dreal
    )],

    # all pointers are _just_ pointers
    #
    # but it's nice to keep track of what
    # they point to ;>
    ptr_t=>[qw(
      ptr pptr fptr ref
    )],


    # strings are so special aren't they
    str_t=>[qw(
      str cstr plstr
    )],

  },


  # one list to rule them all!
  ALL_FLAGS=>sub {
    my $list=$_[0]->LIST;
    return [
      flatten(
        [values %$list],dupop=>1

      ),qw(
        vec2 vec3 vec4 mat2 mat3 mat4
        sign
      ),
    ];

  },

  # regexes for all
  RE=>sub {
    my $list  = $_[0]->LIST;
    my $flags = $_[0]->ALL_FLAGS;

    return {
      ptr_any  => pekey(
        @{$list->{ptr_t}}

      ),
      flag_any => pekey(@$flags),

      map {(
        $ARG=>pekey(@{$list->{$ARG}})

      )} keys %$list
    };
  },


  IDEXOF => sub {
    my $list=$_[0]->LIST;
    return {
      Arstd::Array::IDEXUP(
        0,\&_asis,@{$list->{ezy}}
      ),
      Arstd::Array::IDEXUP(
        2,\&_asis,@{$list->{real}}
      ),

      (map {$ARG=>3} @{$list->{ptr_t}}),
      (map {$ARG=>0} @{$list->{str_t}}),
    };
  },

  # ^maximum power of 2 allowed
  EZY_CAP => sub {
    1 << $_[0]->IDEXOF->{zword}
  },


  # signals for the type generator
  TYPEFLAG => sub {
    my $list=$_[0]->LIST;
    return {
      (map {$ARG=>0x00} @{$list->{defn}}),

      sign     => 0x001,
      real     => 0x002,

      vec      => 0x004,
      mat      => 0x008,

      str      => 0x010,
      cstr     => 0x020,
      plstr    => 0x040,

      str_t    => 0x070,

      ptr      => 0x080,
      pptr     => 0x100,
      fptr     => 0x200,
      ref      => 0x400,

      ptr_t    => 0x7F0,
    };
  },

  # sizes for the bytepacker!
  TYPEPACK => {
    byte   => 'C',
    word   => 'S',
    dword  => 'L',
    qword  => 'Q',
    xword  => 'L[4]',
    yword  => 'L[8]',
    zword  => 'L[16]',
    real   => 'f',
    dreal  => 'd',
    str    => 'Z',
    cstr   => 'Z*',
    plstr  => 'ux',

    # a pointer is __just__ a pointer...
    (map {$ARG=>'P'} qw(ptr pptr fptr ref)),
  },
};


# ---   *   ---   *   ---
# RAM

sub typetab {
  state  $tab={};
  return $tab;
};


# ---   *   ---   *   ---
# make an alias for a type
#
# [0]: byte ptr  ; alias name
# [1]: byte pptr ; array of type flags
#
# [<]: handle to aliased type
#
# [!]: overwrites strings in input array
# [*]: throws on invalid

sub typedef {
  # make copy of input string
  my $name=shift;
  strip($name);

  # fetch actual type and assign it to alias
  typeadd($name=>typefet(@_));

  # give fetched type
  return typetab()->{$name};
};


# ---   *   ---   *   ---
# inserts entry to table
#
# [0]: byte ptr ; typename
# [1]: mem  ptr ; type hashref
#
# [*]: throws on invalid

sub typeadd {
  typetab()->{$_[0]}=$_[1]
  if ! exists typetab()->{$_[0]};

  # ^catch name with underscores or hyphens
  my $alt=flagstrip($_[0]);

  typetab()->{$alt}=typetab()->{$_[0]}
  if $alt ne $_[0] &&! exists typetab()->{$alt};

  # ^catch invalid
  badtype($_[0]) if ! is_valid($_[0]);
  return;
};


# ---   *   ---   *   ---
# can fetch?
#
# [0]: mem  ptr ; type hashref | string
# [<]: bool ; type exists in table

sub is_valid {
  my $type=typename($_[0]);
  return (
      exists(typetab()->{$type})
  &&! is_null(typetab()->{$type})
  );
};


# ---   *   ---   *   ---
# get name of type if passed type
# is a hashref
#
# [0]: mem  ptr ; type hashref | string
# [<]: byte ptr ; name of type (new string)
#
# [*]: gives null on fail

sub typename {
  my $type=shift;
  if(is_hashref($type)) {
    $type=$type->{name};
  } else {
    $type=flagstrip($type);
  };

  $type //= null;
  return $type;
};


# ---   *   ---   *   ---
# get type hashref from string
#
# *IF* you don't already have
# the hashref!
#
# [0]: mem ptr ; type hashref | array of strings
# [<]: mem ptr ; type hashref

sub typefet {
  return (! is_hashref($_[0]))
    ? fetch(@_)
    : $_[0]
    ;
};


# ---   *   ---   *   ---
# gives you an already defined type from
# an array of specifiers, or builds a
# new type from them if no match is found
#
# [0]: byte pptr ; array of strings
# [<]: mem  ptr  ; decl hashref
#
# [!]: overwrites strings in input array
# [*]: throws on fail

sub fetch {
  # cleanup flags
  @_=flagstrip(@_);

  # ^lookup if single string passed
  return typetab()->{$_[0]}
  if @_ == 1 && is_valid($_[0]);

  # lookup via flags
     @_    = map {split qr{\s+},$ARG} @_;
  my $decl = rdflags(@_);

  # ^already defined?
  return    typetab()->{$decl->{name}}
  if exists typetab()->{$decl->{name}};

  # ^else build from declaration ;>
  typebuild($decl);
  return $decl;
};


# ---   *   ---   *   ---
# cleanups flags
#
# [0]: byte pptr ; array of flag names
# [<]: byte pptr ; sanitized (new array)

sub flagstrip {
  my @ar  = @_;
  my $cnt = int @ar;
  my @out = map {
    split qr{\s+},lc $ARG

  } grep {namestrip($ARG)} @ar;

  return ($cnt == 1)
    ? join ' ',@out
    : @out
    ;
};


# ---   *   ---   *   ---
# cleanups unwanted spaces in flag name
#
# [0]: byte ptr ; flag name
# [<]: bool     ; string is not null
#
# [!]: overwrites input string

sub namestrip {
  return 0 if is_null($_[0]);
  my $re=qr{(?:\s+|[\-_]+)};

  $_[0]=~ s[$re][ ]g;
  strip($_[0]);

  return ! is_null($_[0]);
};


# ---   *   ---   *   ---
# reads in type specifiers
#
# [0]: byte pptr ; array of strings
# [<]: mem  ptr  ; decl hashref
#
# [*]: formula for defining vector types
#      makes primitives as a side-effect ;>

sub rdflags {
  # we output to this hashref
  my $out={};

  # extract typedata from specifiers
  typekey($out,@_);
  typevec($out,@_);
  typemask($out,@_);

  # ^modify key/name from flags and cnt
  typename_build($out);

  # give hashref
  return $out;
};


# ---   *   ---   *   ---
# extracts first primitive from
# array of flags
#
# [0]: mem  ptr  ; decl hashref
# [1]: byte pptr ; array of strings
#
# [*]: writes fields to input
# [*]: throws on invalid

sub typekey {
  # get ctx
  my $class = St::cpkg();
  my $re    = $class->RE;
  my $out   = shift;

  # get key
  my ($key)=grep {$ARG=~ $re->{defn}} @_;

  # ^retry?
  ($key)=grep {! ($ARG=~ $re->{ptr_t})} @_
  if is_null($key);

  # ^give up? ;>
  ($key)=grep {$ARG=~ $re->{ptr_t}} @_
  if is_null($key);

  # ^throw missing
  badtype(join ' ',@_) if is_null($key);


  # ignore pointer type when it comes to
  # the type name (it'll be added later)
  my $name=($key=~ $re->{ptr_t})
    ? null()
    : $key
    ;

  # set fields and give
  $out->{key}  = $key;
  $out->{name} = $name;

  return;
};


# ---   *   ---   *   ---
# get element count for vector/matrix types
#
# [0]: mem  ptr  ; decl hashref
# [1]: byte pptr ; array of flags
#
# [!]: overwrites strings in input array
# [*]: writes field to input

sub typevec {
  my $out    = shift;
  my $cnt_re = qr{(vec|mat)(\d+)$};

  my ($cnt)=map {
    ($ARG=~ s[$cnt_re][$1]) ? $2 : () ;

  } @_;

  $out->{cnt}=$cnt//=1;
  return;
};


# ---   *   ---   *   ---
# combines type flags together into
# single integer
#
# [0]: mem  ptr  ; decl hashref
# [1]: byte pptr ; array of flags
#
# [*]: writes field to input

sub typemask {
  # get ctx
  my $out    = shift;
  my $class  = St::cpkg();
  my $type   = $class->TYPEFLAG;

  # OR things together
  my $flags=0x00;
  for(gvalues($type,@_)) {
    $flags |= $type->{$ARG};
  };

  # ^pointers are not real! ;>
     $flags &=~ $type->{real}
  if $flags &   $type->{ptr};

  # ^reals are always signed!
     $flags &=~ $type->{sign}
  if $flags &   $type->{real};

  # make ptr to vec single-elem
      $out->{cnt}  =  1
  ,   $flags      &=~ $type->{vec}
  ,   $flags      &=~ $type->{mat}

  if  $flags      &   $type->{ptr_t};


  # set field and give
  $out->{flags}=$flags;
  return;
};


# ---   *   ---   *   ---
# builds typename from flags
#
# [0]: mem  ptr  ; decl hashref
# [*]: writes field to input

sub typename_build {
  # get ctx
  my $class  = St::cpkg();
  my $type   = $class->TYPEFLAG;

  # prepend 'sign' for signed
  $_[0]->{name}="sign $_[0]->{name}"
  if $_[0]->{flags} & $type->{sign};

  # append (vec)N for vectors/matrices
  for(
    grep {$_[0]->{flags} & $type->{$ARG}}
    qw   (vec mat)
  ) {
    $_[1]="$_[0]->{name} $ARG$_[0]->{cnt}";
  };

  # insert string && pointer specifier
  for(
    grep {$_[0]->{flags} & $type->{$ARG}}
    qw   (str cstr plstr ptr pptr fptr ref)
  ) {
    $_[0]->{name} = "$_[0]->{name} $ARG";
    $_[0]->{key}  = $ARG;
  };

  # cleanup and give
  namestrip($_[0]->{name});
  return;
};


# ---   *   ---   *   ---
# makes a new type (from the result of rdflags!)
#
# [0]: mem ptr ; decl hashref
# [<]: mem ptr ; type hashref

sub typebuild {
  # fetch elem size as a power of 2
  my $class=St::cpkg();
  $_[0]->{ezy}=$class->IDEXOF->{$_[0]->{key}};

  # ^catch bad size
  throw("Bad sizeof key '$_[0]->{key}' "
  .     "(type: $_[0]->{name})"

  ) if ! defined $_[0]->{ezy};


  # get layout (for vector/matrix)
  typelay($_[0]);

  # calc sizes and forbid null size
  typesizing($_[0]);
  badsize($_[0]->{name}) if ! $_[0]->{sizeof};

  # get packing format
  typefmat($_[0]);

  # blank out struct attrs
  voidstruc($_[0]);


  # catch entry exceeds largest elem size
  # NOTE: this is for primitives, not structs
  throw("Type '$_[0]->{name}' exceeds "
  .     ($class->EZY_CAP) . " bytes for "
  .     "element size"

  ) if ($_[0]->{ezy} > $class->EZY_CAP);

  # ^no problems then;
  # ^register and give
  typetab()->{$_[0]->{name}}=$_[0];
  return;
};


# ---   *   ---   *   ---
# determine element distribution for
# vector types
#
# [0]: mem  ptr ; decl hashref
#
# [*]: writes byte ptr layout (new string)
#      directly to input

sub typelay {
  if(is_primvec($_[0])) {
    my $x={
      xword => 2,
      yword => 4,
      zword => 8,

    }->{$_[0]->{key}};

    $_[0]->{layout} = [(1) x $x];
    $_[0]->{cnt}    = $x;
    return;
  };

  # get ctx
  my $class = St::cpkg();
  my $type  = $class->TYPEFLAG;

  # handle implicit vectors
  my ($xmat,$implicit)=typevec_implicit($_[0]);
  my ($cols,$rows)=(0,0);

  # ^proc
  if($xmat) {
    $cols=2*$implicit;
    $rows=$_[0]->{cnt};

    $_[0]->{key}='qword';

  # ^divide matrices into (cnt * cnt)
  } elsif($_[0]->{flags} & $type->{mat}) {
    $cols=$_[0]->{cnt};
    $rows=$_[0]->{cnt};

  # ^divide vectors into (cnt * 1)
  # ^for {cnt == 1}, this makes primitives!
  } else {
    $cols=1;
    $rows=$_[0]->{cnt};
  };


  # get final element count from layout
  $_[0]->{layout} = [($cols) x $rows];
  $_[0]->{cnt}    = $cols * $rows;

  return;
};


# ---   *   ---   *   ---
# makes xword+ *implicitly* a vector
#
# [0]: mem ptr ; decl hashref
# [<]: mem ptr ; [is_matrix,elem cnt] (new array)
#
# [*]: modifies (ezy,cnt) of input

sub typevec_implicit {
  # get ctx
  my $class = St::cpkg();
  my $type  = $class->TYPEFLAG;

  # is element size larger than qword?
  my $xmat     = 0;
  my @implicit = (
      $_[0]->{ezy} > 3
  &&! is_primvec($_[0])

  ) ? (0) x ($_[0]->{ezy} - 3)
    : ()
    ;

  $_[0]->{ezy}=3 if int @implicit;
  for(@implicit) {
    $xmat |= $_[0]->{flags} & $type->{vec};
    $_[0]->{cnt} +=! $xmat;
  };

  return ($xmat,int @implicit);
};


# ---   *   ---   *   ---
# calculates different typevars
#
# [0]: mem  ptr ; decl hashref
# [*]: modifies (ezy,cnt) of input

sub typesizing {
  # get ctx
  my $class = St::cpkg();
  my $type  = $class->TYPEFLAG;

  # calc elem byte/bit/mask size
  my $eby = 1    << $_[0]->{ezy};
  my $ebs = $eby << 3;
  my $ebm = (1 << $ebs)-1;

  # calc total size as a power of 2
  my $tby  = $eby * $_[0]->{cnt};

  my $tzy  = bitsize($tby)-1;
     $tzy += 1 * ((1 << $tzy) < $tby);

  # adjust sizes for string types
  if(is_wstr($_[0])) {
    $ebm   = $ebm | ($ebm << 8);
    $tby <<= 1;
    $ebs <<= 1;

    ++$tzy;
  };

  # write to dst hashref and give
  $_[0]->{sizeof}  = $tby;
  $_[0]->{sizep2}  = $tzy;
  $_[0]->{sizebs}  = $ebs;
  $_[0]->{sizebm}  = $ebm;
  $_[0]->{signbit} = (1 << $ebs-1);

  return;
};


# ---   *   ---   *   ---
# get type is a string/C string/wide string
#
# [0]: mem  ptr ; decl hashref
# [<]: bool     ; type is string

sub is_str {
  my $type=St::cpkg()->TYPEFLAG;
  return ($_[0]->{flags} & $type->{str_t});
};

sub is_cstr {
  my $type=St::cpkg()->TYPEFLAG;
  return ($_[0]->{flags} & $type->{cstr});
};

sub is_wstr {
  my $type=St::cpkg()->TYPEFLAG;
  return (
  # value is marked as string...
    is_str($_[0])

  # ^and elem size is wide
  # ^(single byte would be ezy == 0)
  && ($_[0]->{flags}  & $type->{plstr}
  ||  $_[0]->{ezy}   == 1)
  );
};


# ---   *   ---   *   ---
# value is a primitive vector

sub is_primvec {
  my $re=qr{(?:xword|yword|zword)};
  return $_[0]->{key}=~ $re;
};


# ---   *   ---   *   ---
# get format for bytepacker
#
# [0]: mem  ptr ; decl hashref
# [*]: modifies (ezy,cnt) of input

sub typefmat {
  # get ctx
  my $class = St::cpkg();
  my $type  = $class->TYPEFLAG;

  # is this a signed value?
  my $sign=(
      ($_[0]->{flags} & $type->{sign} )
  &&! ($_[0]->{flags} & $type->{ptr_t})
  );

  # ^if so, lowercase the pack char
  my $fmat=$class->TYPEPACK->{$_[0]->{key}};
     $fmat=lc $fmat if $sign;


  # handle wide strings
  if(is_wstr($_[0])) {
    $fmat='ux';

  # ^everything else (that is not a string)
  # ^has to include element count
  } elsif(! is_str($_[0]) &&! is_primvec($_[0])) {
    $fmat="$fmat\[$_[0]->{cnt}]"
  };


  # set format field and give
  $_[0]->{packof}=$fmat;
  return;
};


# ---   *   ---   *   ---
# writes empty values for struc attrs
#
# [0]: mem  ptr ; decl hashref
# [*]: modifies (ezy,cnt) of input

sub voidstruc {
  $_[0]->{struc_t}   = [];
  $_[0]->{struc_i}   = [];
  $_[0]->{struc_off} = [];

  return;
};


# ---   *   ---   *   ---
# build structure or union from
# other types!

sub struc($name,$src=undef) {
  return struc_inner(struc=>$name,$src);
};

sub union($name,$src=undef) {
  return struc_inner(union=>$name,$src);
};

sub struc_inner($cmd,$name,$src=undef) {
  # case insensitivity!
  $name=lc $name;

  # fetch existing?
  do {
    my $have=St::tabfetch(
      $name => typetab(),
      (! defined $src) => (\&badtype,$name),
    );
    return $have
    if $have && $have ne '--define';
  };

  # parse input
  my $tree  = Tree::C->rd($src);
  my @expr  = $tree->to_expr();
  my @field = ($cmd eq 'union')
    ? unionparse(@expr)
    : strucparse(@expr)
    ;

  return strucmake($cmd,$name,@field);
};

sub strucmake($cmd,$name,@field) {
  # stop if type already defined when
  # recursing (may happen during parse)
  if(exists typetab()->{$name}) {
    return typetab()->{$name};
  };


  # ^array as hash
  my @fv  = nvalues(\@field);
  my @fk  = nkeys(\@field);

  my $out = {
    name    => $name,
    struc_i => [map {
      # unroll labels for anonymous blocks
      my $label = $fk[$ARG];
      my $type  = $fv[$ARG]->{type};
      ($type->{name}=~ anonblk_re())
        ? @{$type->{struc_i}}
        : $label
        ;

    } 0..$#fk],
  };
  $out->{struc_t}=[map {
    # also unroll offsets for anonymous blocks
    ($ARG->{type}->{name}=~ anonblk_re())
      ? @{$ARG->{type}->{struc_t}}
      : $ARG->{type}->{name}
      ;

  } @fv];

  # ^combine sizes
  ($cmd eq 'union')
    ? unionsizing($out,\@fv)
    : strucsizing($out,\@fv)
    ;

  # ^forbid null size
  badsize($name) if ! $out->{sizeof};

  # combine layouts
  $out->{layout}=[map {
    if($ARG->{type}->{name}=~ anonblk_re()) {
      my @have=@{$ARG->{type}->{layout}};
      (@have) x $ARG->{cnt};

    } else {
      my $have=$ARG->{type}->{layout};
      int(flatten($have)) * $ARG->{cnt};
    };

  } @fv];

  # combine packing formats
  $out->{packof}=($cmd eq 'union')
    ? unionpacking(@fv)
    : strucpacking(@fv)
    ;

  # write to table
  typeadd($name => $out);

  # ^make pointer-to variations ;>
  for(qw(ptr pptr ref)) {
    typedef("$name $ARG" => $ARG);
  };
  return $out;
};


# ---   *   ---   *   ---
# used to detect anonymous structs;
# in such a case, an element can have
# an offset larger than 0
#
# [*]: const re

sub anonstruc_re {
  return qr{^_anonstruct?\d+_$};
};

sub anonunion_re {
  return qr{^_anonunion\d+_$};
};

sub anonblk_re {
  return qr{^_anon(?:union|struct?)\d+_$};
};


# ---   *   ---   *   ---
# combines sizes of structure fields
#
# [0]: mem ptr ; type hashref
# [1]: mem ptr ; decl hashref array (struc fields)
#
# [*]: writes to destination struc

sub strucsizing {
  # get args
  my ($out,$field)=(shift,shift);

  # calculate offsets and total size
  # in the same loop
  my $i   = 0;
  my $tby = 0;
  my $tbs = 0;
  $out->{struc_off}=[map {
    my $cnt=$ARG->{cnt};
    my $ezy=$tby;

    $tby += $ARG->{type}->{sizeof} * $cnt;
    $tbs += $ARG->{type}->{sizebs} * $cnt;

    # for anonymous strucs, we give offset for
    # each individual field
    if($ARG->{type}->{name}=~ anonstruc_re()) {
      map {$ezy + $ARG}
      @{$ARG->{type}->{struc_off}};

    # ^ for regular fields we give copy of total
    #   size before element increase ;>
    } else {
      $ezy;
    };

  } @$field];

  strucsizing_set($out,$tby,$tbs);
  return;
};


# ---   *   ---   *   ---
# ^same thing, but for unions
#
# [0]: mem ptr ; type hashref
# [1]: mem ptr ; decl hashref array (struc fields)
#
# [*]: writes to destination struc

sub unionsizing {
  # get args
  my ($out,$field)=(shift,shift);

  # calculate offsets and total size
  # in the same loop
  my $i   = 0;
  my $tby = 0;
  my $tbs = 0;
  $out->{struc_off}=[map {
    my $cnt=$ARG->{cnt};
    my $ezy=$tby;

    # size is determined by largest element
    if($ARG->{type}->{sizeof} * $cnt > $tby) {
      $tby=$ARG->{type}->{sizeof} * $cnt;
      $tbs=$ARG->{type}->{sizebs} * $cnt;
    };

    # anonymous struc means its elements
    # can be accessed directly;
    #
    # in this case, elements may not start
    # at offset zero
    ($ARG->{type}->{name}=~ anonstruc_re())
      # unroll element offsets for anon
      ? @{$ARG->{type}->{struc_off}}

      # regular element starts at zero
      : 0
      ;

  } @$field];

  strucsizing_set($out,$tby,$tbs);
  return;
};


# ---   *   ---   *   ---
# ^common proc to both Fs

sub strucsizing_set($out,$tby,$tbs) {
  # get total as a power of 2
  my $tzy=bitsize($tby)-1;
  ++$tzy while (1 << $tzy) < $tby;

  # set fields and give
  $out->{sizeof}=$tby;
  $out->{sizep2}=$tzy;
  $out->{sizebs}=$tbs;
  $out->{sizebm}=-1;
  return;
};


# ---   *   ---   *   ---
# determine packing format for struc
#
# [0]: mem  pptr ; struc fields
# [<]: byte ptr  ; packing format (new string)

sub strucpacking {
  return cat(map {
    my $sfmat  = $ARG->{type}->{packof};
    my $cnt    = $ARG->{cnt};
    my ($have) = $sfmat=~ m[(\d+)];

    $sfmat=~ s[\d+][$cnt] if $cnt > $have;
    $sfmat;

  } @_);
};


# ---   *   ---   *   ---
# ^for union
#
# [0]: mem  pptr ; struc fields
# [<]: byte ptr  ; packing format (new string)

sub unionpacking {
  my $big=typefet('byte');
  for(@_) {
    my ($cur,$prev)=(
      $ARG->{type}->{sizeof},
      $big->{sizeof}
    );
    $big=$ARG->{type} if (
        $cur > $prev
    &&! is_str($big)
    );
  };

  return $big->{packof};
};


# ---   *   ---   *   ---
# modify existing structure!

sub restruc($name,$src) {
  # get type to overwrite
  my $old=struc($name);
  return null() if ! $old;

  # ^generate new on dummy
  my $new=struc('RESTRUC-DUMMY',$src);

  # ^overwrite!
  %$old=%$new;
  $old->{name}=$name;

  # cleanup and give
  delete typetab()->{'RESTRUC-DUMMY'};
  return $old;
};


# ---   *   ---   *   ---
# parse single value decl
#
# [0]: mem ptr ; expression hashref
# [<]: mem ptr ; name => typename[cnt]

sub letparse {
  # last token is name
  # everything else is type
  my ($decl,$defv)=gsplit($_[0]->{expr},qr{=});

  # ^get [cnt] part of name[cnt]
  my $array_re = qr{\[(.+)\]$};
  my $type_re  = qr{^((?:[^\s,]|\s*,\s*)+)\s};

  my $cnt=($decl=~ s[$array_re][])
    ? $1
    : 1
    ;

  strip($cnt);

  # ^_now_ take last token as name
  $_[0]->{expr}=$decl;
  my $name=tokenpop($_[0]);

  # joining the rest of the expression
  # gives us the type!
  my $type=join("_",$_[0]->{cmd},$_[0]->{expr});

  # give [name=>hashref]
  return ($name=>{
    type => typefet($type),
    cnt  => $cnt,
    defv => $defv,
  });
};


# ---   *   ---   *   ---
# ^a whole bunch of em!
#
# [0]: byte ptr ; structure declaration
# [<]: mem  ptr ; [name => typename[cnt]] array
#
# [*]: adds padding

sub strucparse {
  # read each field and add padding in-between
  my $total  = 0;
  my $large  = 0;
  my $padcnt = 0;
  my @out=map {
    # get next field
    my @have  = letparse($ARG);
    my $align = $have[1]->{type}->{sizeof};

    # get size is largest yet
    $large=$align if $align > $large;

    # add padding before field if current
    # byte is not aligned to size
    (autopad($total,$align,$padcnt),@have);

  } strucparse_inner(@_);

  # add padding at end if total is not a
  # multiple of largest alignment
  return (@out,autopad($total,$large,$padcnt));
};


# ---   *   ---   *   ---
# it's strucparse but without padding ;>
#
# [0]: byte ptr ; structure declaration
# [<]: mem  ptr ; [name => typename[cnt]] array
#
# [*]: adds padding only at end

sub unionparse {
  return (
    map {letparse($ARG)}
    strucparse_inner(@_)
  );
};


# ---   *   ---   *   ---
# reuse C syntax to recursively
# break down a (possibly) nested block
#
# [0]: mem  pptr ; expression hashref array
# [<]: byte pptr ; expressions (new array)

sub strucparse_inner {
  # to keep track of anonymous union/struc
  state $uid=0;

  # iter each block
  my @out      = ();
  my $struc_re = qr{\b(?:union|struct?)\b};

  for(@_) {
    my $cmd=$ARG->{cmd};
    my @blk=@{$ARG->{blk}};

    # have (union|struc) (name|null) {...}
    if(@blk && ($cmd=~ $struc_re)) {
      # get block name (or make name for anonymous)
      my $anon=is_null($ARG->{expr});
      my $name=(! $anon)
        ? tokenpop($ARG)
        : "_anon${cmd}" . ++$uid . '_'
        ;

      # recurse to generate required type
      my @field=($cmd eq 'union')
        ? strucparse(@blk)
        : unionparse(@blk)
        ;

      my $type=strucmake($cmd=>$name=>@field);

      # ^ give reference to struc as a single field
      #   in place of block definition
      push @out,{cmd=>$type->{name},expr=>$name};

    # ^plain field, give asis
    } else {
      push @out,$ARG;
    };
  };

  return @out;
};


# ---   *   ---   *   ---
# calculates padding for structs
#
# [0]: word ; total size
# [1]: word ; alignment
# [2]: word ; padding field counter

sub autopad {
  return () if ! $_[1];
  my @pad  = ();
  my $need = $_[0] % $_[1];
  if($need) {
    @pad=letparse({
      cmd  => 'byte',
      expr => "_autopad_${_[2]}[$need]",
    });
    ++$_[2];
  };
  return @pad;
};


# ---   *   ---   *   ---
# called on import
#
# [*]: builds defaults types

sub import {
  # handle default Expoter stuff
  my @out=__PACKAGE__->export_to_level(1,@_);

  # skip if default types already built
  return @out if int keys %{typetab()};

  # make primitives
  for(qw(
    byte  word  dword qword
    xword yword zword
    real  dreal
  )) {
    typedef("$ARG"      => "$ARG");
    typedef("$ARG ptr"  => "$ARG ptr");
    typedef("$ARG pptr" => "$ARG pptr");
    typedef("$ARG ref"  => "$ARG ref");

    typedef("sign $ARG" => "sign $ARG")
    if $ARG ne 'real' && $ARG ne 'dreal';
  };

  for(qw(cstr plstr)) {
    typedef("$ARG"     => "$ARG");
    typedef("$ARG ptr" => "$ARG ptr");
  };

  # make vector aliases
  for my $t(qw(real dword sign_dword)) {
    # first letter gives *element* type
    my $i={
      real       => null(),
      dword      => 'u',
      sign_dword => 'i',

    }->{$t};

    # make vec[2-4] for element type
    for my $sz(2..4) {
      my @elem=qw(x y);
      push @elem,'z' if $sz > 2;
      push @elem,'w' if $sz > 3;
      for(@elem) {
        $ARG="$t $ARG;";
      };
      struc("${i}vec$sz"=>cat(@elem));
    };

    # ^make mat[2-4] for element type
    for my $sz(2..4) {
      struc("${i}mat$sz"=>"${i}vec$sz col[$sz];");
    };
  };

  return @out;
};


# ---   *   ---   *   ---
# warn of malformed/unexistent type
#
# [0]: byte ptr ; type name

sub badtype {
  throw("Invalid type: '$_[0]'");
};


# ---   *   ---   *   ---
# ^forbid zero-size type
#
# [0]: byte ptr ; type name

sub badsize {
  throw("type '$_[0]' has a total size of zero");
};


# ---   *   ---   *   ---
# ^forbid void deref!
#
# [0]: byte ptr ; type name

sub badptr {
  throw("'$_[0]' is incomplete; cannot deref");
};


# ---   *   ---   *   ---
1; # ret
