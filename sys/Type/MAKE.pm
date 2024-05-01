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
# lyeb,

# ---   *   ---   *   ---
# TODO: at [*fetch]:
#
# * separate the code that procs
#   the ptr_t and ptr_w flags
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

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);
  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Warnme;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::String;
  use Arstd::Re;

  use Arstd::IO;

  use Vault 'ARPATH';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    typefet
    typedef

    badtype
    badptr

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM


  # to get ize as a power of 2...
  Readonly my $ASIS   => sub {$_[0]=>$_[1]};


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

      wide

    )],


    # all pointers are relative in peso
    # this means we must track their size too!
    #
    # the additional keywords are added to
    # avoid confusing names such as byte byte ptr
    ptr_w=>[qw(
      tiny short mean long

    )],

    ptr_t=>[qw(
      ptr pptr fptr

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

      array_flatten(
        [values %$list],dupop=>1

      ),qw(

        vec2 vec3 vec4 mat2 mat3 mat4
        sign

      ),

    ];

  },

  # regexes for all
  RE => sub {

    my $list  = $_[0]->LIST;
    my $flags = $_[0]->ALL_FLAGS;

    return {

      ptr_any  => re_pekey(

        @{$list->{ptr_t}},
        @{$list->{ptr_w}},

        ( map {"${ARG}ptr"} @{$list->{ptr_w}}),

      ),

      flag_any => re_pekey(@$flags),


      map {(
        $ARG=>re_pekey(@{$list->{$ARG}})

      )} keys %$list

    };

  },


  IDEXOF => sub {

    my $list=$_[0]->LIST;

    return {

      IDEXUP(0,$ASIS,@{$list->{ezy}}),
      IDEXUP(0,$ASIS,@{$list->{ptr_w}}),
      IDEXUP(2,$ASIS,@{$list->{real}}),

      (map {$ARG=>1} @{$list->{ptr_t}}),
      (map {$ARG=>0} @{$list->{str_t}}),

      wide => 1,

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


      tiny     => 0x010,
      tinyptr  => 0x010,

      short    => 0x020,
      shortptr => 0x020,

      mean     => 0x040,
      meanptr  => 0x040,

      long     => 0x080,
      longptr  => 0x080,


      str      => 0x100,
      cstr     => 0x200,
      plstr    => 0x400,


      ptr_w    => 0x0F0,
      str_t    => 0x700,
      ptr      => 0x7F0,

    };

  },


  # sizes for the bytepacker!
  TYPEPACK => {

    byte   => 'C',
    tiny   => 'C',

    word   => 'S',
    wide   => 'S',
    short  => 'S',

    dword  => 'L',
    mean   => 'L',

    qword  => 'Q',
    long   => 'Q',
    xword  => 'Q',
    yword  => 'Q',
    zword  => 'Q',

    real   => 'f',
    dreal  => 'd',

    str    => 'Z',
    cstr   => 'Z*',
    plstr  => 'u',

  },

};

# ---   *   ---   *   ---
# GBL

  our $Table=Vault::cached(
    'Table' => \&define_base

  );

# ---   *   ---   *   ---
# warn of malformed/unexistent type

sub badtype($name) {

  Warnme::invalid 'type',

  obj  => $name,
  give => null;

};

# ---   *   ---   *   ---
# ^forbid zero-size type

sub badsize($name) {

  warnproc "type '%s' has a total size of zero",

  args => [$name],
  give => null;

};

# ---   *   ---   *   ---
# ^forbid void deref!

sub badptr($name) {

  warnproc "'%s' is incomplete; cannot deref",

  args => [$name],
  give => null;

};

# ---   *   ---   *   ---
# get type hashref from string
#
# *IF* you don't already have
# the hashref!

sub typefet(@src) {

  return (! is_hashref($src[0]))
    ? fetch(@src)
    : $src[0]
    ;

};

# ---   *   ---   *   ---
# make an alias for a type

sub typedef($dst,@src) {

  $Table->{$dst}=typefet @src
  or return badtype;

  return $Table->{$dst};

};

# ---   *   ---   *   ---
# cleanups unwanted spaces in typename

sub namestrip($name) {

  state $re=qr{(?:$NSPACE_RE|[\-_]+)};

  $name=~ s[$re][ ];
  strip(\$name);

  return $name;

};

# ---   *   ---   *   ---
# cleanups flags

sub flagstrip(@ar) {

  my @out=map {
    split $NSPACE_RE,lc namestrip($ARG)

  } grep {$ARG} @ar;


  return (@ar == 1)
    ? join ' ',@out
    : @out
    ;

};

# ---   *   ---   *   ---
# formula for defining vector types
# makes primitives as a side-effect ;>

sub _fetch(@flags) {


  # get ctx
  my $class     = St::cpkg;
  my $RE        = $class->RE;
  my $TYPEFLAG  = $class->TYPEFLAG;

  # add default value for mask flags
  map {$ARG='short' if $ARG eq 'ptr'} @flags;


  # get key
  my ($key)=grep {$ARG=~ $RE->{defn}} @flags;

  # ^retry?
  map  {$key //=  $ARG}
  grep {$ARG   =~ $RE->{ptr_w}} @flags

  if ! defined $key;

  # ^throw missing
  return badtype join ' ',@flags
  if ! defined $key;


  # get element count
  my $cnt=undef;
  map {
     $cnt //= $1
  if $ARG   =~ s[(\d+)$][]

  } @flags;


  $cnt //= 1;


  # combine flags
  my $flags=0x00;

  map  {$flags |= $TYPEFLAG->{$ARG}}
  grep {$ARG ne 'ptr'} @flags;


  # pointers are not real! ;>
     $flags &=~ $TYPEFLAG->{real}
  if $flags &   $TYPEFLAG->{ptr};


  # reals are always signed!
     $flags &=~ $TYPEFLAG->{sign}
  if $flags &   $TYPEFLAG->{real};


  # make unique typename
  my $name=($key=~ $RE->{ptr_w})
    ? $NULLSTR
    : $key
    ;


  map  {$name  = "$ARG $name"}
  grep {$flags & $TYPEFLAG->{$ARG}}
  qw   (sign);

  map  {$name  = "$name $ARG$cnt"}
  grep {$flags & $TYPEFLAG->{$ARG}}
  qw   (vec mat);

  map  {$name  = "$name ${ARG}";$key=$ARG}
  grep {$flags & $TYPEFLAG->{$ARG}}
  qw   (str cstr plstr);

  map  {$name  = "$name ${ARG}ptr";$key=$ARG}
  grep {$flags & $TYPEFLAG->{$ARG}}
  qw   (tiny short mean long);


  # ^cleanup unwanted spaces
  $name=namestrip($name);


  # make ptr to vec single-elem
      $cnt    =  1
  ,   $flags &=~ $TYPEFLAG->{vec}
  ,   $flags &=~ $TYPEFLAG->{mat}

  if  $flags &   $TYPEFLAG->{ptr};


  # give hashref
  return {

    key   => $key,
    cnt   => $cnt,

    name  => $name,
    flags => $flags,

  };

};

# ---   *   ---   *   ---
# ^continued

sub fetch(@flags) {


  # get ctx
  my $class     = St::cpkg;
  my $TYPEFLAG  = $class->TYPEFLAG;
  my $TYPEPACK  = $class->TYPEPACK;
  my $IDEXOF    = $class->IDEXOF;


  # cleanup flags
  @flags=flagstrip(@flags);

  # ^lookup if single string passed
  return $Table->{$flags[0]}
  if @flags == 1 && exists $Table->{$flags[0]};


  # lookup via flags, fail on invalid
     @flags = map {split $NSPACE_RE,$ARG} @flags;
  my $type  = _fetch(@flags);

  return undef if $type eq null;


  # ^already defined?
  return    $Table->{$type->{name}}
  if exists $Table->{$type->{name}};


  # ^unpack
  my $flags = $type->{flags};
  my $name  = $type->{name};
  my $key   = $type->{key};
  my $cnt   = $type->{cnt};


  # fetch elem size as a power of 2
  my $ezy=$IDEXOF->{$key};

  # make xword+ *implicitly* a vector!
  my $xmat     = 0;
  my @implicit = ($ezy > 3)
    ? (0) x ($ezy - 3)
    : ()
    ;

  map {

    $ezy   =  3;

    $xmat |=  $flags & $TYPEFLAG->{vec};
    $cnt  +=! $xmat;

  } @implicit;


  # determine element distribution
  my $cols;
  my $rows;

  # ^handle implicit vectors!
  if($xmat) {

    $cols = 2*int @implicit;
    $rows = $cnt;

    $key  = 'qword';

  # ^divide matrices into (cnt * cnt)
  } elsif($flags & $TYPEFLAG->{mat}) {
    $cols = $cnt;
    $rows = $cnt;

  # ^divide vectors inot (cnt * 1)
  # ^for {cnt == 1}, this makes primitives!
  } else {
    $cols = 1;
    $rows = $cnt;

  };


  # get final element count from layout
  my $layout = [($cols) x $rows];
     $cnt    = $cols * $rows;


  # calc elem byte/bit/mask size
  my $eby = 1    << $ezy;
  my $ebs = $eby << 3;
  my $ebm = (1 << $ebs)-1;

  # calc total size as a power of 2
  my $tby  = $eby * $cnt;

  my $tzy  = bitsize($tby)-1;
     $tzy += 1 * ((1 << $tzy) < $tby);


  # get format for bytepacker
  my $sign =
      ($flags & $TYPEFLAG->{sign} )
  &&! ($flags & $TYPEFLAG->{ptr});

  my $fmat = $TYPEPACK->{$key};
     $fmat = lc $fmat if $sign;


  # ^handle string packing formats!
  if( ($flags & $TYPEFLAG->{str_t})
  &&! ($flags & $TYPEFLAG->{ptr_w})

  ) {

    # we'll implement this eventually ;>
    if($key eq 'str') {
      nyi('peso strings');

    # absolute corner case:
    # PACKING WIDE STRINGS
    } elsif($name=~ q{\b(?:wide|plstr)\b}) {

      $fmat   = 'u';
      $ebm    = $ebm | ($ebm << 8);

      $tby  <<= 1;
      $ebs  <<= 1;

      $tzy++;

    };


  # ^and *this* for everything else!
  } else {$fmat="$fmat\[$cnt]"};


  # forbid null size
  badsize $name if ! $tby;

  # make Table entry
  my $out={

    packof    => $fmat,

    sizeof    => $tby,
    sizep2    => $tzy,
    sizebs    => $ebs,
    sizebm    => $ebm,

    signbit   => (1 << $ebs-1),

    layout    => $layout,
    name      => $name,

    struc_t   => [],
    struc_i   => [],

    struc_off => [],

  };


  # undef if entry exceeds largest size
  $Table->{$name}=($tby <= $class->EZY_CAP)
    ? $out
    : undef
    ;

  return $Table->{$name};

};

# ---   *   ---   *   ---
# make shorthands for certain
# common types

sub define_base() {


  typedef ptr   => 'word short';
  typedef cstr  => 'byte cstr';
  typedef plstr => 'wide plstr';

# NYI
#  typedef str   => 'byte str';
#  typedef wstr  => 'wide str';


  # make vector aliases
  map {


    # first letter gives *element* type
    my $ezy = $ARG;
    my $i   = {

      real        => $NULLSTR,

      dword       => 'u',
      sign_dword  => 'i',

    }->{$ezy};


    # ^make vec[2-4],mat[2-4] for element type
    map {

      my $type=$ARG;
      my $name="$i$type";

      map {
         typedef "$name$ARG" => ($ezy,"$type$ARG")

      } 2..4;


    } qw(vec mat);


  } qw(real dword sign_dword);


  return $Table;

};

# ---   *   ---   *   ---
1; # ret
