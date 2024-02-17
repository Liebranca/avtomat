#!/usr/bin/perl
# ---   *   ---   *   ---
# TYPE
# I'd rather call it 'width'
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
  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Re;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(
    sizeof
    packof
    typeof

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.03.9;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    -autoload=>[qw(

      pevec

    )],

   }};


  # min to max size for all base types
  Readonly our $EZY_LIST=>[qw(
    byte  word  dword qword
    xword yword zword

  )];

  # ^real dword/real qword
  Readonly our $REAL_LIST=>[qw(
    real dreal

  )];

  # valid *element* sizes for base types
  # ie what a vector can contain!
  Readonly our $PRIM_LIST=>[qw(
    byte word dword qword real dreal

  )];

  # ^ALL the sizes!
  Readonly our $DEFN_LIST=>[
    @$EZY_LIST,@$REAL_LIST

  ];


  # all pointers are relative in peso
  # this means we must track their size too!
  #
  # the additional keywords are added to
  # avoid confusing names such as byte byte ptr
  #
  # ^(which is valid peso, by the way)
  Readonly our $PTR_W_LIST=>[qw(
    tiny short mean long

  )];

  Readonly our $PTR_T_LIST=>[qw(
    ptr pptr fptr

  )];


  # strings are so special aren't they
  Readonly our $STR_T_LIST=>[qw(
    str cstr plcstr

  )];


  # regexes for all
  Readonly my $EZY_RE   => re_pekey(@$EZY_LIST);
  Readonly my $REAL_RE  => re_pekey(@$REAL_LIST);

  Readonly my $PTR_T_RE => re_pekey(@$PTR_T_LIST);
  Readonly my $PTR_W_RE => re_pekey(@$PTR_W_LIST);

  Readonly my $STR_T_RE => re_pekey(@$STR_T_LIST);


# ---   *   ---   *   ---
# formula for defining vector types
# makes primitives as a side-effect ;>

Readonly my $ASIS   => sub {$_[0]=>$_[1]};
Readonly my $IDEXOF => {

  IDEXUP(0,$ASIS,@$EZY_LIST),
  IDEXUP(0,$ASIS,@$PTR_W_LIST),
  IDEXUP(2,$ASIS,@$REAL_LIST),

  (map {$ARG=>1} @$PTR_T_LIST),
  (map {$ARG=>0} @$STR_T_LIST),

};

Readonly my $EZY_CAP  => 1 << $IDEXOF->{zword};
Readonly my $TYPEFLAG => {

  sign  => 0x001,
  real  => 0x002,

  vec   => 0x004,
  mat   => 0x008,

  tiny  => 0x010,
  short => 0x020,
  mean  => 0x040,
  long  => 0x080,

  ptr   => 0x0F0,

  str   => 0x100,
  cstr  => 0x200,

};


Readonly my $TYPEPACK=>{

  byte  => 'C',
  tiny  => 'C',

  word  => 'S',
  wide  => 'S',
  short => 'S',

  dword => 'L',
  mean  => 'L',

  qword => 'Q',
  long  => 'Q',

  real  => 'F',
  dreal => 'D',

};

sub define($key,$cnt,@flags) {


  # combine flags
  my $flags=0x00;

  push @flags,'real' if $key=~ $REAL_RE;
  map  {$flags |= $TYPEFLAG->{$ARG}} @flags;


  # pointers are not real! ;>
     $flags &=~ $TYPEFLAG->{real}
  if $flags &   $TYPEFLAG->{ptr};

  # reals are always signed!
     $flags &=~ $TYPEFLAG->{sign}
  if $flags &   $TYPEFLAG->{real};

  # make typename
  my $name=$key;

  map  {$name="$ARG $name"}
  grep {$flags & $TYPEFLAG->{$ARG}}
  qw   (sign);

  map  {$name="$name $ARG$cnt"}
  grep {$flags & $TYPEFLAG->{$ARG}}
  qw   (mat vec);

  map  {$name="$ARG $name";$key=$ARG}
  grep {$flags & $TYPEFLAG->{$ARG}}
  qw   (tiny short mean long);


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
      $flags & $TYPEFLAG->{sign}
  &&! ($flags & $TYPEFLAG->{ptr})
  ;

  my $fmat = $TYPEPACK->{$key};
     $fmat = lc $fmat if $sign;


  # make table entry
  my @out=($name=>{

    packof => "$fmat\[$cnt]",

    sizeof => $tby,
    sizep2 => $tzy,
    sizebs => $ebs,
    sizebm => $ebm,

    layout => $layout,
    flags  => $flags,


  });


  # discard entry if it exceeds largest size
  return ($tby <= $EZY_CAP) ? @out : ();

};

# ---   *   ---   *   ---
# ^bat-call

sub define_list($cnt,@flags) {

  map {define(@$ARG)}
  map {[$ARG=>$cnt,@flags]}

  @$DEFN_LIST

};

# ---   *   ---   *   ---
# ^bat-call for vectors/matrices

sub define_vec($type,@flags) {
  map {define_list $ARG=>$type,@flags} 2..4;

};

sub define_mat(@flags) {
  map {define_vec $ARG=>@flags} qw(vec mat);

};

# ---   *   ---   *   ---
# ^bat-call for all base types
# excluding pointers

sub define_base() {

  map {
    (define_list 1=>@$ARG),
    (define_mat     @$ARG)

  } [],['sign'];

};

# ---   *   ---   *   ---
# ^makes aliases for primitives

sub define_prim_lis($tab) { return (

  ptr  => $tab->{'short word ptr'},

)};

# ---   *   ---   *   ---
# ^makes aliases for vectors

sub define_vec_lis($type,$tab) {

  # first letter says elem type!
  my $i={
    real         => $NULLSTR,
    dword        => 'u',

    'sign dword' => 'i',

  }->{$type};

  map {(
    "${i}vec$ARG" => $tab->{"$type vec$ARG"}

  )} 2..4;

};

# ---   *   ---   *   ---
# ^make aliases for strings

sub define_str_lis($tab) { return (

  cstr  => $tab->{'short byte cstr'},
  wcstr => $tab->{'short wide cstr'},

  str   => $tab->{'short byte str'},
  wstr  => $tab->{'short wide str'},

)};

# ---   *   ---   *   ---
# ^THE FINAL CHAPTER

sub define_all() {

  my $tab={define real=>2,'mean','vec'};
#     $tab={%$tab,define_lis $tab};


  use Fmat;
  fatdump(\$tab);

};

define_all;
exit;

# ---   *   ---   *   ---
# get bytesize of type

Readonly my $SIZEOF=>{

  IDEXUP_P2(0,sub {$_[0]=>$_[1]},@$EZY_LIST),
  IDEXUP_P2(0,sub {$_[0]=>$_[1]},@$PTR_W_LIST),

  (map {$ARG=>2} @$PTR_T_LIST),
  (map {$ARG=>2} @$STR_T_LIST),

};

Readonly my $SIZEP2=>{

  IDEXUP(0,sub {$_[0]=>$_[1]},@$EZY_LIST),
  IDEXUP(0,sub {$_[0]=>$_[1]},@$PTR_W_LIST),

  (map {$ARG=>1} @$PTR_T_LIST),
  (map {$ARG=>1} @$STR_T_LIST),

};

Readonly my $SIZEOF_RE => qr{
  ($EZY_RE|$PTR_W_RE|$REAL_RE)

}x;

sub sizeof($name) {


  # read keywords as last/first/middle
  my @ar=map {

    ($name=~ s[$ARG][])
      ? lc $1
      : 'word'
      ;

  } qr{$SIZEOF_RE$},qr{^$SIZEOF_RE},$SIZEOF_RE;


  # ^have ptr?
  my @ptr_t=grep {
    $ARG=~ qr{$PTR_T_RE|$PTR_W_RE}

  } @ar;


  # ^give size
  return (@ptr_t)
    ? $SIZEOF->{$ptr_t[-1]}
    : $SIZEOF->{$ar[0]}
    ;

};

# ---   *   ---   *   ---
# get bitmask for type
# elem mask if vec/mat

Readonly my $SIZEBM=>{

  IDEXUP_P2(0,sub {
    $_[0]=>(1 << ($_[1] << 3))-1

  },@$EZY_LIST),

  IDEXUP_P2(0,sub {
    $_[0]=>(1 << ($_[1] << 3))-1

  },@$PTR_W_LIST),

  (map {$ARG=>0xFFFF} @$PTR_T_LIST),
  (map {$ARG=>0xFFFF} @$STR_T_LIST),

};

# ---   *   ---   *   ---
# get packing fmat for type

sub packof($name) {

  my $tab={
    'cstr'   => 'Z',
    'plcstr' => '$Z',

  };

  return (! exists $tab->{lc $name})
    ? $TYPEPACK->{sizeof($name) << 3}
    : $tab->{lc $name}
    ;

};

# ---   *   ---   *   ---
# get type-list for pack
# accto provided bytesize

sub typeof($size) {

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
# shorthands: check against re

sub is_valid($class,$name) {
  return $name=~ $SIZEOF_RE;

};

sub is_str($class,$name) {
  return $name=~ $STR_T_RE;

};

sub is_ptr($class,$name) {
  return $name=~ $PTR_T_RE;

};

# ---   *   ---   *   ---
# completes a peso => (lang)
# translation table

sub xlatetab($langclass,@tab) {

  # array as hash
  my $ti=0;

  my @tk=array_keys(\@tab);
  my @tv=array_values(\@tab);

  # ^walk
  return { map {

    my $peso = $ARG;
    my $lang = $tv[$ti++];

    map {$langclass->batlis($ARG,$peso)} @$lang;


  } @tk };


};

# ---   *   ---   *   ---
1; # ret
