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
  use Arstd::Int;
  use Arstd::String;
  use Arstd::IO;
  use Arstd::PM;

  use Type::MAKE;
  use St;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    struc
    strucf
    restruc

    sizeof
    packof
    typeof
    derefof
    offsetof

    typefet
    typedef

    badtype
    badptr

    PEVAR
    PESTRUC

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.04.6;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $DEFAULT=>typefet 'word';

# ---   *   ---   *   ---
# kindly shut up

BEGIN {

  $SIG{__WARN__}=sub {

    my $warn=shift;

    return if $warn=~ qr{
      non-portable
    | format \s wrapped

    }x;

    warn $warn;

  };

};

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

  strip(\$name);


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

sub struc($name,$src=undef) {


  # fetch existing?
  do {

    my $have=St::tabfetch(

      $name => $Type::MAKE::Table,

      (! defined $src) => (
        \&badtype,
        $name

      ),

    );

    return $have
    if $have && $have ne '--define';

  };


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
  my @off = ();

  map {

    my $cnt=$fv[$fi++]->{cnt};

    push @off,$tby;

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

      my $cnt    = $fv[$fi++]->{cnt};
      my ($have) = $ARG=~ m[(\d+)];

      $ARG=~ s[\d+][$cnt] if $cnt > $have;
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

    packof    => $fmat,

    sizeof    => $tby,
    sizep2    => $tzy,
    sizebs    => $tbs,
    sizebm    => -1,

    layout    => [@layout],
    name      => $name,

    struc_t   => [@typename],
    struc_i   => [@idex],
    struc_off => [@off],

  };


  # save and give
  $Type::MAKE::Table->{$name}=$out;
  return $out;

};

# ---   *   ---   *   ---
# ^modify existing structure!

sub restruc($name,$src) {


  # get type to overwrite
  my $old=struc $name;
  return null if ! $old;

  # ^generate new on dummy
  my $new=struc 'RESTRUC-DUMMY',$src;


  # ^overwrite!
  %$old=%$new;
  $old->{name}=$name;

  # cleanup and give
  delete $Type::MAKE::Table->{'RESTRUC-DUMMY'};
  return $old;

};

# ---   *   ---   *   ---
# ^errme for field access

sub badstrucf($name) {

  Warnme::invalid 'struc field',

  obj  => [$name],
  give => null;

};

# ---   *   ---   *   ---
# fetch struc field data

sub strucf($type,$name) {

  # get idex of field
  my $names = $type->{struc_i};
  my $idex  = array_iof $names,$name;

  # ^validate
  return badstrucf "$type->{name}.$ARG"
  if ! defined $idex;


  # ^get type
  my $field_t = $type->{struc_t}->[$idex];
     $field_t = typefet $field_t;


  return ($field_t,$idex);

};

# ---   *   ---   *   ---
# get bytesize of type

sub sizeof($name,@field) {


  # validate input
  my $type=typefet $name
  or return badtype $name;

  # ^prepare output
  my $out  = $type->{sizeof};
     $name = $type->{name};


  # sizeof struc.field?
  map {


    # get next (sub)field
    my ($field_t,$idex)=
      strucf $type,$ARG;


    # calc size when last elem reached
    if($ARG == $field[-1]) {
      my $cnt = $type->{layout}->[$idex];
         $out = $cnt * $field_t->{sizeof};

    # ^recurse if names pending
    } else {
      $type  = $field_t;
      $name .= ".$ARG";

    };


  } @field;


  return $out;

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

  } qw(yword xword qword dword word byte);


  return @out;

};

# ---   *   ---   *   ---
# removes ptr flags from type

sub derefof($ptr_t) {

  # get base type
  $ptr_t=typefet $ptr_t
  or return null;


  # strip flags
  my $re   = Type::MAKE->RE->{ptr_any};

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
# get pos of struc field

sub offsetof($type,$field) {

  # validate input
  $type=typefet $type
  or return null;

  # give zero if not a struc!
  return 0 if ! @{$type->{struc_t}};


  # get struc field
  my ($field_t,$idex)=
    strucf $type,$field;

  # ^validate and give
  return (length $field_t)
    ? $type->{struc_off}->[$idex]
    : $field_t
    ;

};

# ---   *   ---   *   ---
# get minimum-sized primitive
# big enough to hold N bits

sub bitfit($size,$bytes=0) {

  $size <<= 3 if $bytes;

  my $out  = null;
  my @list = @{Type::MAKE->LIST->{ezy}};

  for my $type(@list) {

    $type=typefet $type;

    if($type->{sizebs} >= $size) {
      $out=$type;
      last;

    };

  };


  return $out;

};

# ---   *   ---   *   ---
# get pointer type accto
# how many bytes we need!

sub ptr_by_size($class,$ptrv) {

  my $need = bitsize   $ptrv;
     $need = int_urdiv $need,8;

  my ($out) = grep {
    $need <= sizeof $ARG

  } @{Type::MAKE->LIST->{ptr_w}};

  return $out;

};

# ---   *   ---   *   ---
# can fetch?

sub is_valid($class,$type) {

  if(is_hashref $type) {
    $type=$type->{name};

  };

  $type //= null;
  return exists $Type::MAKE::Table->{$type};

};

# ---   *   ---   *   ---
# proto: check name against re

sub _typeisa($class,$type,$key) {

  if(is_hashref $type) {
    $type=$type->{name};

  };

  $type //= null;
  return int ($type=~ Type::MAKE->RE->{$key});

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
    real:real
    prim:prim

  ),

);

# ---   *   ---   *   ---
# shit's killing me

sub is_base_ptr($class,$type) {

  state $re=Type::MAKE->RE->{ptr_any};


  if(is_hashref $type) {
    $type=$type->{name};

  };

  $type //= null;
  return int ($type=~ qr{^$re$});

};

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
