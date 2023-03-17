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
  use Arstd;
  use Vault;

  use Type;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;
  use Peso::Ipret;

  use parent 'Emit';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.3;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $Typetab=Vault::cached(

    '$Typetab',\$Typetab,
    \&xltab,

# ---   *   ---   *   ---

    q[sbyte]=>['int8_t'],

    q[byte]=>[
      'uchar','uint8_t','unsigned char'

    ],

    q[swide]=>[
      'short','int16_t'

    ],

    q[wide]=>[
      'ushort','uint16_t'

    ],

# ---   *   ---   *   ---

    q[byte_str]=>['char*'],
    q[wide_str]=>['wchar_t*'],

# ---   *   ---   *   ---

    q[brad]=>['uint','uint32_t'],
    q[sbrad]=>['int','int32_t'],

    q[word]=>[
      'ulong','uint64_t','size_t','uintptr_t',

    ],

    q[sword]=>[
      'long','int64_t','intptr_t',

    ],

    q[real]=>['float'],
    q[daut]=>['double'],

    q[pe_void]=>['void'],

  );

# ---   *   ---   *   ---

  Readonly my $OPEN_GUARDS=>

q[#ifndef __$:fname;>_H__
#define __$:fname;>_H__

#ifdef __cplusplus
extern "C" {
#endif
];


# ---   *   ---   *   ---

  Readonly my $CLOSE_GUARDS=>

q[#ifdef __cplusplus
};
#endif
#endif // __$:fname;>_H__
];

# ---   *   ---   *   ---

sub get_typetab($class) {return $Typetab};
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

  Peso::Ipret::pesc(

    \$s,

    fname=>$fname,
    note=>Emit::Std::note($O{author},q[//]),

    include=>$O{include},
    define=>$O{define},

    guards=>($O{add_guards})
      ? $OPEN_GUARDS
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

  Peso::Ipret::pesc(
    \$s,

    fname=>$fname,

    guards=>($O{add_guards})
      ? $CLOSE_GUARDS
      : $NULLSTR
      ,

  );

  return $s;

};

# ---   *   ---   *   ---
# pastes code inside a function definition

sub fnwrap($class,$name,$code,%O) {

  # defaults
  $O{rtype}//='int';
  $O{args}//='void';

# ---   *   ---   *   ---

  my $s="$O{rtype} $name($O{args})".
    "{\n$code\n\n};\n\n";

  return $s;

};

# ---   *   ---   *   ---

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

  }};

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
1; # ret
