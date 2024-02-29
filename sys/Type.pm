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
  use Warnme;


  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::String;
  use Arstd::IO;
  use Arstd::PM;

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

    badtype
    badptr

    PEVAR
    PESTRUC

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.04.2;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $DEFAULT=>typefet 'word';


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


  # fetch/validate type array
  my @typename = map {$ARG->{type}} @fv;
  my @type     = map {
     typefet $ARG
  or badtype $ARG

  } @typename;

  0 == int grep {$ARG eq null} @type
  or return null;


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


  # forbid null size
  Type::MAKE::badsize $name if ! $tby;

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

  my $type=typefet $name;

  return (defined $type)
    ? $type->{sizeof}
    : badtype $name
    ;

};

# ---   *   ---   *   ---
# get packing fmat for type

sub packof($name) {

  my $type=typefet $name;

  return (defined $type)
    ? $type->{packof}
    : badtype $name
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
# removes ptr flags from type

sub derefof($ptr_t) {

  # get base type
  $ptr_t=typefet $ptr_t
  or return null;


  # strip flags
  my $re   = $Type::MAKE::RE->{ptr_any};

  my $name = $ptr_t->{name};
     $name =~ s[$re][]sxmg;

  # ^clear blanks
  $name=Type::MAKE::namestrip($name);


  # fetch and validate
  my $type=typefet $name
  or return badptr $ptr_t->{name};


  return $type;

};

# ---   *   ---   *   ---
# can fetch?

sub is_valid($class,$type) {
  return defined typefet $type;

};

# ---   *   ---   *   ---
# proto: check name against re

sub _typeisa($class,$type,$key) {

  $type=typefet $type
  or return 0;

  return $type->{name}=~
    $Type::MAKE::RE->{$key};

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$class->_typeisa]=>q[$class,$type],


  map {

    my ($sufix,$name)=
      split $COLON_RE,$ARG;

    ["is_$sufix" => "\$type,'$name'"];

  }

  qw (
    str:str_t
    ptr:ptr_any

  ),

);

# ---   *   ---   *   ---
# errme

sub warn_redef($name) {

  Warnme::redef 'type',

  obj  => $name,
  give => 0;

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
