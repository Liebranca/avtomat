#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT C
# tools for outputting C code
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb
# ---   *   ---   *   ---

# deps
package Emit::C;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Vault;
  use Type;

  use Arstd::Array;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;
  use Peso::Ipret;

  use parent 'Emit';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.5;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $TYPES=>[

    q[sbyte]=>['int8_t'],

    q[byte]=>[
      'uint8_t','uchar','unsigned char'

    ],

    q[swide]=>[
      'int16_t','short',

    ],

    q[wide]=>[
      'uint16_t','ushort',

    ],

    q[byte_str]=>['char*'],
    q[wide_str]=>['wchar_t*'],

    q[brad]=>['uint32_t','uint'],
    q[sbrad]=>['int32_t','int'],

    q[word]=>[
      'uint64_t','ulong','size_t','uintptr_t',

    ],

    q[sword]=>[
      'int64_t','long','intptr_t',

    ],

    q[real]=>['float'],
    q[daut]=>['double'],

    q[pe_void]=>['void'],

  ];

# ---   *   ---   *   ---

  Readonly our $OPEN_GUARDS=>

q[#ifndef __$:fname;>_H__
#define __$:fname;>_H__

#ifdef __cplusplus
extern "C" {
#endif
];


# ---   *   ---   *   ---

  Readonly our $CLOSE_GUARDS=>

q[#ifdef __cplusplus
};
#endif
#endif // __$:fname;>_H__
];

# ---   *   ---   *   ---
# GBL

  our $Typetab=Vault::cached(

    'Typetab',

    \&xltab,
    @$TYPES

  );

# ---   *   ---   *   ---

sub typetrim($class,$typeref) {

  # until I care enough to handle this spec
  $$typeref=~ s[\b const \b][]sgx;

  Emit->typetrim($typeref);

};

# ---   *   ---   *   ---
# header guards

sub boiler_open($class,$fname,%O) {

  $fname=uc $fname;

# ---   *   ---   *   ---


  my $s=q[$:note;>
$:guards;>
// ---   *   ---   *   ---
// deps

$:iter (path=>$O{include})
  q{  }."#include $path\n"

;>

// ---   *   ---   *   ---
// ROM

$:iter (

  name=>[array_keys($O{define})],
  value=>[array_values($O{define})],

) q{  }."#define $name $value\n"

;>

// ---   *   ---   *   ---

];


# ---   *   ---   *   ---

  no strict 'refs';

  Peso::Ipret::pesc(

    \$s,

    fname   => $fname,
    note    => Emit::Std::note($O{author},q[//]),

    include => $O{include},
    define  => $O{define},

    guards  => ($O{add_guards})
      ? ${"$class\::OPEN_GUARDS"}
      : $NULLSTR
      ,

  );

  return $s;

};

# ---   *   ---   *   ---

sub boiler_close($class,$fname,%O) {

  $fname=uc $fname;

# ---   *   ---   *   ---


  my $s=q[

// ---   *   ---   *   ---

$:guards;>

];


# ---   *   ---   *   ---

  no strict 'refs';

  Peso::Ipret::pesc(
    \$s,

    fname=>$fname,

    guards=>($O{add_guards})
      ? ${"$class\::CLOSE_GUARDS"}
      : $NULLSTR
      ,

  );

  return $s;

};

# ---   *   ---   *   ---
# turn list of args into string

sub arglist_str($class,$args,%O) {

  # defaults
  $O{nl}//=0;

  my $out=$NULLSTR;

  if($O{nl}) {

    $out=
      "\n  "
    . (join ",\n  ",@$args)

    . "\n\n"
    ;

  } else {
    $out=join q[,],@$args;

  };

  return $out;

};

# ---   *   ---   *   ---
# pastes code inside a function definition

sub fnwrap($class,$name,$code,%O) {

  # defaults
  $O{rtype} //= 'int';
  $O{args}  //= 'void';

  my $s="$O{rtype} $name($O{args}) ".
    "{\n$code\n\n};\n\n";

  return $s;

};

# ---   *   ---   *   ---
# ^gives decl

sub fnwrap_decl($class,$name,%O) {

  # defaults
  $O{rtype} //= 'int';
  $O{args}  //= 'void';

  return "$O{rtype} $name($O{args});\n";

};

# ---   *   ---   *   ---
# ^gives both as array

sub fnwrap_ar($class,$name,$code,%O) {

  my $out=[];

  # defaults
  $O{rtype}   //= 'int';
  $O{args}    //= [];
  $O{args_nl} //= 1;

  $O{class} //= $NULLSTR;

  my $args=$class->arglist_str(
    $O{args},nl=>$O{args_nl}

  );

  my $cname     = $O{class};

  my $decl_args = $args;
  my $decl_type = $O{rtype};
  my $decl_name = $name;

  # remove class name from decl
  if(length $cname) {

    $cname="$cname\::";
    my $re=qr{$cname};

    $decl_name=~ s[$re][];
    $decl_type=~ s[$re][];
    $decl_args=~ s[$re][]sxmg;

  };

  # make decl
  push @$out,$class->fnwrap_decl(

    $decl_name,

    rtype => $decl_type,
    args  => $decl_args,

  );

  # make def
  push @$out,$class->fnwrap(

    "$cname$name",$code,

    rtype => $O{rtype},
    args  => $args,

  );

  return $out;

};

# ---   *   ---   *   ---
# ^sugar for main

sub mfwrap($class,$code) {

  return $class->fnwrap(

    'main',$code,

    rtype => 'int',
    args  => 'int argc,char** argv',

  );

};

# ---   *   ---   *   ---
# give list of attributes
# sorted by size (wider first)

sub attrlist($class,@vars) {

  my %vars  = @vars;
  my @names = array_keys(\@vars);

  my @sorted=sort {

    sizeof($class->typecon($vars{$a}))
  < sizeof($class->typecon($vars{$b}))

  } @names;

  return join "\n",map {
    "$vars{$ARG} $ARG;"

  } @sorted;

};

# ---   *   ---   *   ---
# outdated "data section" generator

sub datasec($class,$name,$type,@items) {

  my $s=$NULLSTR;

  if($type eq 'enum') {
    $s.="$type {\n";

  } else {
    $s.="$type ${name}[]={\n";

  };

# ---   *   ---   *   ---

  my $i=0;
  for my $item(@items) {

    $s.=$item;
    if($i ne $#items) {
      $s.=q{,};

    };

    $i++;

  };

# ---   *   ---   *   ---

  if($type eq 'enum') {
    $s.=",\n $name\n\n};\n\n";

  } else {
    $s.="\n\n};\n\n";

  };

  return $s;

};

# ---   *   ---   *   ---
# paste case [value]: [code]

sub switch_case($class,$value,$code) {

  my $out=($value eq 'default')
    ? "default:\n  $code\n\n"
    : "case $value:\n  $code\n\n"
    ;

  return $out;

};

# ---   *   ---   *   ---
# ^paste case [key]: [value]
# for [key => value] in %O

sub switch_tab($class,$x,%O) {

  my $out=$NULLSTR;

  map {
    $out.=$class->switch_case($ARG,$O{$ARG})

  } keys %O;

  return "switch($x) {\n\n$out\n};\n";

};

# ---   *   ---   *   ---
# makes peso-C translation table
# saves you from typing pointer
# types manually

sub xltab(%table) {

  for my $key(qw(byte_str wide_str)) {
  for my $indlvl(1..2) {

    my $peso_ind=$Type::Indirection_Key->[$indlvl-1];
    my $c_ind=q[*] x $indlvl;

    my $subtab=$table{"${key}_$peso_ind"}=[];

    for my $ctype(@{$table{$key}}) {
      push @$subtab,"$ctype$c_ind";

    };

  }};

# ---   *   ---   *   ---

  for my $key(keys %table) {
  next if $key=~ m[_str_];

  for my $indlvl(1..3) {

    my $peso_ind=$Type::Indirection_Key->[$indlvl-1];
    my $c_ind=q[*] x $indlvl;

    my $subtab=$table{"${key}_$peso_ind"}=[];

    for my $ctype(@{$table{$key}}) {
      push @$subtab,"$ctype$c_ind";

    };

  }};

# ---   *   ---   *   ---

  my $result={};

  for my $key(keys %table) {
    for my $ctype(@{$table{$key}}) {
      $result->{$ctype}=$key;

    };

    # make first ctype the
    # preferred one for reverse
    # typecon ops

    my $pref=$table{$key}->[0];
    $result->{$key}=$pref;

  };

# ---   *   ---   *   ---

  my %strtypes=(

    byte=>[

      map
        {$ARG=substr $ARG,0,(length $ARG)-1}
        @{$table{byte_str}}

    ],

    wide=>[

      map
        {$ARG=substr $ARG,0,(length $ARG)-1}
        @{$table{wide_str}}

    ],

  );

# ---   *   ---   *   ---

  for my $key(qw(byte wide)) {
  for my $ctype(@{$strtypes{$key}}) {
    $result->{$ctype}=$key;

  }};

  return $result;

};

# ---   *   ---   *   ---
# DEPRECATED: use Emit::Cpp
#
# clears C stuff from hpp guards

sub cpptrim($class,$sref) {

  $$sref=~ s[

    \#ifdef \s+ __cplusplus
    [^\#]+
    \#endif

  ][]sxmg;

};

# ---   *   ---   *   ---
1; # ret
