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

  use List::Util qw(sum);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::String;
  use Arstd::IO;

  use Type::MAKE;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    struc

    sizeof
    packof
    typeof
    derefof

    typefet
    typedef

    PEVAR
    PESTRUC

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.04.2;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# parse single value decl

sub PEVAR($expr) {

  # get X => Y[Z]
  state $array_re = qr{\[(.+)\]$};
  state $type_re  = qr{^((?:[^\s,]|\s*,\s*)+)\s};


  # first "X[,Y]?" is value type
  $expr=~ s[$type_re][];

  my $type =  $1;
     $type =~ s[$NSPACE_RE][];


  # ^followed by "name[size]"
  my $name =  $expr;
  my $cnt  = ($name=~ s[$array_re][]) ? $1 : 1 ;


  # ^give hashref
  return $name=>{
    type => $type,
    cnt  => $cnt,

  };

};

# ---   *   ---   *   ---
# ^a whole bunch of em!

sub PESTRUC($src) {

  map   {PEVAR  $ARG}

  grep  {length $ARG}
  map   {strip(\$ARG);$ARG}

  split $SEMI_RE,$src;

};

# ---   *   ---   *   ---
# build structure from
# other types!

sub struc($name,$src) {


  # already defined?
  return    $Type::MAKE::Table->{$name}
  if exists $Type::MAKE::Table->{$name};


  # parse input
  my @field=PESTRUC $src;

  # ^array as hash
  my $fi=0;
  my @fk=array_keys(\@field);
  my @fv=array_values(\@field);


  # fetch type array
  my @typename = map {$ARG->{type}} @fv;
  my @type     = map {typefet $ARG} @typename;

  # ^combine sizes
  my $tby = 0;
  my $tbs = 0;

  map {

    my $cnt=$fv[$fi++]->{cnt};

    $tby += $ARG->{sizeof} * $cnt;
    $tbs += $ARG->{sizebs} * $cnt;

  } @type;

  # ^get total as a power of 2
  my $tzy = bitsize($tby)-1;
  while((1 << $tzy) < $tby) {$tzy++};


  # combine layouts
     $fi     = 0;
  my @layout = map {
    array_flatten($ARG->{layout})
  * $fv[$fi++]->{cnt}

  } @type;


  # combine packing formats
     $fi   = 0;
  my $fmat = join $NULLSTR,(

    map {
      $ARG=~ s[\d+][$fv[$fi++]->{cnt}];
      $ARG;

    } map {$ARG->{packof}} @type

  );


  # get idex of each field
     $fi   = 0;
  my @idex = map {$ARG} @fk;


  # make Table entry
  my $out={

    packof  => $fmat,

    sizeof  => $tby,
    sizep2  => $tzy,
    sizebs  => $tbs,
    sizebm  => -1,

    layout  => [@layout],
    name    => $name,

    struc_t => [@typename],
    struc_i => [@idex],

  };


  # save and give
  $Type::MAKE::Table->{$name}=$out;
  return $out;

};

# ---   *   ---   *   ---
# get bytesize of type

sub sizeof($name) {

  my $type=typefet($name);

  return (defined $type)
    ? $type->{sizeof}
    : throw_invalid_type($name)
    ;

};

# ---   *   ---   *   ---
# get packing fmat for type

sub packof($name) {

  my $type=typefet($name);

  return (defined $type)
    ? $type->{packof}
    : throw_invalid_type($name)
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
# removes "ptr" from typename

sub derefof($name) {

  state $re=qr{
    $Type::MAKE::RE->{ptr_w}
  | $Type::MAKE::RE->{ptr_t}

  };


  $name=~ s[$re][]sxmg;
  return Type::MAKE::namestrip($name);

};

# ---   *   ---   *   ---
# shorthands: check against re

sub is_valid($class,$name) {
  return defined typefet($name);

};

sub is_str($class,$name) {
  return $name=~ $Type::MAKE::RE->{str_t};

};

sub is_ptr($class,$name) {
  return $name=~ $Type::MAKE::RE->{ptr_t};

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
