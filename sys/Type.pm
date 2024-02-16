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
  use Arstd::Hash;
  use Arstd::Re;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    sizeof
    packof

    array_typeof

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


  # sigil flags
  #
  # used to identify a type's key using
  # only a number and binary operators
  Readonly my  $SF=>{

    size  => 0x00FFF,

    sign  => 0x01000,
    real  => 0x02000,
    ptr   => 0x04000,
    str   => 0x08000,

    thin  => 0x10000,
    short => 0x20000,
    wide  => 0x40000,
    long  => 0x80000,

  };


  # map size to format
  Readonly our $PACK_SIZES=>hash_invert({

    'Q'=>64,
    'L'=>32,
    'S'=>16,
    'C'=>8,

  },duplicate=>1);


  # for matching widths
  Readonly our $EZY_LIST=>[qw(
    byte  word  dword qword
    xword yword zword

  )];

  Readonly our $REAL_LIST=>[qw(
    real dreal

  )];

  # all pointers are relative in peso
  # this means we must track their size too!
  #
  # the additional keywords are added to
  # avoid confusing names such as byte byte ptr
  #
  # ^(which is valid peso, by the way)
  Readonly our $PTR_W_LIST=>[qw(
    thin short wide long

  )];

  Readonly our $PTR_T_LIST=>[qw(
    ptr pptr

  )];

  Readonly our $STR_T_LIST=>[qw(
    str constr cstr plcstr

  )];


  Readonly our $EZY_RE   => re_pekey(@$EZY_LIST);
  Readonly our $REAL_RE  => re_pekey(@$REAL_LIST);

  Readonly my $PTR_T_RE  => re_pekey(@$PTR_T_LIST);
  Readonly our $PTR_W_RE => re_pekey(@$PTR_W_LIST);

  Readonly my $STR_T_RE  => re_pekey(@$STR_T_LIST);


  Readonly our $WIDTH_RE => qr{
    ($EZY_RE|$PTR_W_RE|$REAL_RE)

  }x;


  Readonly my $WIDTH=>{

    IDEXUP_P2(0,sub {$_[0]=>$_[1]},@$EZY_LIST),
    IDEXUP_P2(0,sub {$_[0]=>$_[1]},@$PTR_W_LIST),

    (map {$ARG=>2} @$PTR_T_LIST),
    (map {$ARG=>2} @$STR_T_LIST),

  };

# ---   *   ---   *   ---
# get bytesize of type

sub sizeof($name) {


  # read keywords as last/first/middle
  my @ar=map {

    ($name=~ s[$ARG][])
      ? lc $1
      : 'word'
      ;

  } qr{$WIDTH_RE$},qr{^$WIDTH_RE},$WIDTH_RE;


  # ^have ptr?
  my @ptr_t=grep {
    $ARG=~ qr{$PTR_T_RE|$PTR_W_RE}

  } @ar;


  # ^give size
  return (@ptr_t)
    ? $WIDTH->{$ptr_t[-1]}
    : $WIDTH->{$ar[0]}
    ;

};

# ---   *   ---   *   ---
# ^get packing char for type ;>

sub packof($name) {

  my $tab={
    'cstr'   => 'Z',
    'plcstr' => '$Z',

  };

  return (! exists $tab->{lc $name})
    ? $PACK_SIZES->{sizeof($name) << 3}
    : $tab->{lc $name}
    ;

};

# ---   *   ---   *   ---
# get type-list for pack
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
# shorthand: check against re

sub is_str($class,$name) {
  return $name=~ m[$STR_T_RE];

};

sub is_ptr($class,$name) {
  return $name=~ m[$PTR_T_RE];

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
