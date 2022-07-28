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
package emit::c;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

  use emit::std;

  use peso::type;
  use peso::ipret;

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

  our $TYPETAB={};

  peso::type::xltab(

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

    'word float'=>{sig=>[qw(float)]},
    'long float'=>{sig=>[qw(double)]},

  );

# ---   *   ---   *   ---

sub typecon($type) {

  if(exists $TYPETAB{$type}) {
    $type=$TYPETAB{$type};

  };

  return $type;

};

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

  return peso::ipret::pesc(

    $s,

    name=>$name,
    note=>emit::std::note($O{author},q[//]),

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

  return peso::ipret::pesc(
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
  $O{author}//=$emit::std::ON_NO_AUTHOR;

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

  my $dst="$O{rtype} $name($O{args})".
    "{\n$code\n\n};\n\n";

  return $dst;

};

# ---   *   ---   *   ---
1; # ret
