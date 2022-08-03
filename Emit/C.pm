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
  use Storable;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

  use Type;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;
  use Peso::Ipret;

  use parent 'Emit';

# ---   *   ---   *   ---

  Readonly my $OPEN_GUARDS=>

q[#ifndef __$:name;>_H__
#define __$:name;>_H__

#ifdef __cplusplus
extern "C" {
#endif
];


# ---   *   ---   *   ---

  Readonly my $CLOSE_GUARDS=>

q[#ifdef __cplusplus
};
#endif
#endif // __$:name;>_H__
];

# ---   *   ---   *   ---

  our $TYPETAB=Vault::cached(

    'TYPETAB',

    \$TYPETAB,
    \&Type::xltab,

# ---   *   ---   *   ---

    -PTR_RULES=>{
      key=>q{*},
      fmat=>'$type%s'

    },

    -UNSIG_RULES=>{
      key=>'unsigned',
      fmat=>'%s $type',

    },

# ---   *   ---   *   ---

    byte=>{
      sig=>[qw(char int8_t)],
      unsig=>[qw(uchar uint8_t)],

    },

    wide=>{
      sig=>[qw(short int16_t wchar_t)],
      unsig=>[qw(ushort uint16_t)],

    },

# ---   *   ---   *   ---

    word=>{
      sig=>[qw(int int32_t)],
      unsig=>[qw(uint uint32_t)],

    },

    long=>{

      sig=>[qw(long int64_t intptr_t)],

      unsig=>[qw(
        ulong uint64_t
        size_t uintptr_t

      )],

    },

    'word real'=>{sig=>[qw(float)]},
    'long real'=>{sig=>[qw(double)]},

  );

# ---   *   ---   *   ---
# worse way possible to make SUPER find this var

sub get_typetab($class) {return $TYPETAB};

# ---   *   ---   *   ---
# header guards

sub boiler_open($name,%O) {

  $name=uc $name;

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

  name=>[keys %{$O{define}}],
  value=>[values %{$O{define}}],

) q{  }."#define $name $value\n"

;>

// ---   *   ---   *   ---

];


# ---   *   ---   *   ---

  return Peso::Ipret::pesc(

    $s,

    name=>$name,
    note=>Emit::Std::note($O{author},q[//]),

    include=>$O{include},
    define=>$O{define},

    guards=>($O{add_guards})
      ? $OPEN_GUARDS
      : $NULLSTR
      ,

  );

};

# ---   *   ---   *   ---

sub boiler_close($name,%O) {

  $name=uc $name;

# ---   *   ---   *   ---


  my $s=q[

// ---   *   ---   *   ---

$:guards;>

];


# ---   *   ---   *   ---

  return Peso::Ipret::pesc(
    $s,name=>$name,

    guards=>($O{add_guards})
      ? $CLOSE_GUARDS
      : $NULLSTR
      ,

  );

};

# ---   *   ---   *   ---
# puts code in-between two pieces of boiler

sub codewrap($fname,%O) {

  # defaults
  $O{add_guards}//=0;
  $O{include}//=[];
  $O{define}//={};
  $O{body}//=$NULLSTR;
  $O{args}//=[];
  $O{author}//=$Emit::Std::ON_NO_AUTHOR;

  my $s=$NULLSTR;

  $s.=boiler_open($fname,%O);

  if(length ref $O{body}) {
    my $call=$O{body};
    $s.=$call->($fname,@{$O{args}});

  } else {
    $s.=$O{body};

  };

  $s.=boiler_close($fname,%O);

  return $s;

};

# ---   *   ---   *   ---
# pastes code inside a function definition

sub fnwrap($name,$code,%O) {

  # defaults
  $O{rtype}//='int';
  $O{args}//='void';

# ---   *   ---   *   ---

  my $s="$O{rtype} $name($O{args})".
    "{\n$code\n\n};\n\n";

  return $s;

};

# ---   *   ---   *   ---

sub datasec($name,$type,@items) {

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
1; # ret
