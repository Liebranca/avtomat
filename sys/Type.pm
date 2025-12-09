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
  use v5.42.0;
  use strict;
  use warnings;

  use Scalar::Util qw(looks_like_number);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_hashref);

  use Arstd::Bytes qw(bitsize);
  use Arstd::Int qw(urdiv);
  use Arstd::String qw(cat strip gstrip gsplit);
  use Arstd::Array qw(nkeys nvalues iof);
  use Arstd::throw;
  use Arstd::stoi;
  use Arstd::PM qw(subwraps);

  use Type::MAKE qw(
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
  use parent 'St';


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    struc
    strucf
    restruc

    sizeof
    packof
    typeof
    derefof
    offsetof

    typename
    typefet
    typedef
    typetab

    badtype
    badptr
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.04.7';
  our $AUTHOR  = 'IBN-3DILA';
  sub errsafe {return 1};


# ---   *   ---   *   ---
# ROM

St::vconst {
  DEFAULT=>typefet 'word',
};


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
# fetch struc field data

sub strucf($type,$name) {
  # get idex of field
  my $names = $type->{struc_i};
  my $idex  = iof $names,$name;

  # ^validate
  return badstrucf("$type->{name}.$ARG")
  if ! defined $idex;


  # ^get type
  my $field_t = $type->{struc_t}->[$idex];
     $field_t = typefet($field_t);


  return ($field_t,$idex);
};


# ---   *   ---   *   ---
# ^errme for field access

sub badstrucf($name) {
  throw "Invalid struc field '$name'";
};


# ---   *   ---   *   ---
# get bytesize of type

sub sizeof($name,@field) {
  # validate input
  my $type=typefet($name)
  or return badtype($name);

  # ^prepare output
  my $out  = $type->{sizeof};
     $name = $type->{name};


  # sizeof struc.field?
  for(@field) {
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
  };


  return $out;
};


# ---   *   ---   *   ---
# get packing fmat for type

sub packof($name) {
  my $type=typefet($name);
  return (defined $type)
    ? $type->{packof}
    : badtype($name)
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
  $ptr_t=typefet($ptr_t)
  or return null;

  # strip flags
  my $re   = Type::MAKE->RE->{ptr_any};
  my $name = $ptr_t->{name};
     $name =~ s[$re][]sxmg;

  # ^clear blanks
  Type::MAKE::namestrip($name);

  # fetch and validate
  return typefet($name);
};


# ---   *   ---   *   ---
# get pos of struc field

sub offsetof($type,$field) {
  # validate input
  $type=typefet($type)
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
    $type=typefet($type);
    if($type->{sizebs} >= $size) {
      $out=$type;
      last;
    };
  };

  return $out;
};


# ---   *   ---   *   ---
# type found in table; plain wrapper

sub is_valid($class,$type) {
  return Type::MAKE::is_valid($type);
};

sub is_base($class,$type) {
  return Type::MAKE::is_base($type);
};


# ---   *   ---   *   ---
# remove entry from table

sub rm($class,$type) {
  return if $class->is_base($type);

  $type=typename($type);
  delete typetab()->{$type}
  if exists typetab()->{$type};

  return;
};


# ---   *   ---   *   ---
# proto: check name against re

sub _typeisa($class,$type,$key) {
  $type=typename($type);
  return int ($type=~ Type::MAKE->RE->{$key});
};


# ---   *   ---   *   ---
# ^icef*ck

subwraps(
  q[$class->_typeisa]=>q[$class,$type],
  map {
    my ($sufix,$name)=split qr{:},$ARG;
    ["is_$sufix" => "\$type,'$name'"];

  } qw (
    str:str_t
    ptr:ptr_any
    real:real
    prim:prim
  ),
);


# ---   *   ---   *   ---
# shit's killing me

sub is_base_ptr($class,$type) {
  my $re=Type::MAKE->RE->{ptr_any};
  $type=typename($type);

  return int ($type=~ qr{^$re$});
};


# ---   *   ---   *   ---
# errme

sub warn_redef($name) {
  throw  "Redefinition of type '$name'";

};


# ---   *   ---   *   ---
# completes a peso => (lang)
# translation table

sub xlatetab($langclass,@tab) {
  # array as hash
  my $ti=0;
  my @tk=nkeys(\@tab);
  my @tv=nvalues(\@tab);

  # ^walk
  return { map {
    my $peso = $ARG;
    my $lang = $tv[$ti++];

    map {$langclass->add($ARG,$peso)} @$lang;

  } @tk };
};


# ---   *   ---   *   ---
# ^back and forth from table

sub xlate($lang,$type) {
  my $class = "Type\::$lang";
  my $name  = (is_hashref $type)
    ? $type->{name}
    : $type
    ;

  my $out   = $class->RTable->{$name};
     $out //= $class->Table->{$name};

  throw "No $lang translation for type: '$name'"
  if ! defined $out;

  return $out;
};


# ---   *   ---   *   ---
# ^generate structure!

sub xlate_struc($lang,$type) {
  $type=typefet($type)
  if ! is_hashref($type);

  my $i=0;
  return map {
    my $stype = xlate($lang=>$ARG);
    my $name  = $type->{struc_i}->[$i++];

    [$stype,$name];

  } @{$type->{struc_t}};
};


# ---   *   ---   *   ---
# ~~

sub xlate_expr {
  my ($nd)=@_;
  my ($name,@defv)=gsplit($nd->{expr},qr{=});
  for(@defv) {
    $ARG=join(' ',map {
      if(looks_like_number($ARG)
      || $ARG=~ qr{^\d+}) {
        stoi($ARG);

      } else {$ARG};

    } gsplit($ARG,qr{\s+}));
  };
  if(@defv) {
    @defv=join '=',@defv;
  };
  push @defv,xlate_expr($ARG) for @{$nd->{blk}};

  my @type=gsplit($name,qr{\s+});
     $name=pop @type;

  return (@type)
    ? (typefet(@type),$name=>@defv)
    : (@defv)
    ;
};


# ---   *   ---   *   ---
1; # ret
