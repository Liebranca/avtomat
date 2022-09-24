#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT PYTHON
# absolute disgust
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Emit::Python;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Array;

  use Chk;
  use Shb7;

  use Vault;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;
  use Peso::Ipret;

  use parent 'Emit';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $Typetab=Vault::cached(

    '$Typetab',\$Typetab,
    \&xltab,

# ---   *   ---   *   ---

    q[byte]=>[q(byte)],
    q[syte]=>[q(syte)],
    q[wide]=>[q(wide)],
    q[side]=>[q(side)],

# ---   *   ---   *   ---

    q[byte_str]=>[q(charstar)],
    q[wide_str]=>[q{star(wide)}],

# ---   *   ---   *   ---

    q[long]=>[q(long)],
    q[song]=>[q(song)],

    q[word]=>[q(word)],
    q[sord]=>[q(sord)],

    q[real]=>[q(real)],
    q[daut]=>[q(double)],

# ---   *   ---   *   ---

    q[__pe_void_ptr]=>[q(voidstar)],
    q[__pe_void]=>[q(None)],

  );

# ---   *   ---   *   ---

  Readonly my $OPEN_GUARDS=>

q[#!/usr/bin/python
$:note;>

# ---   *   ---   *   ---
# get system stuff

import os,sys;

ARPATH:str=os.env('ARPATH');
if(ARPATH.'/lib/' not in sys.path):
  sys.path.append(ARPATH.'/lib/');

from Avt.cwrap import *;

# ---   *   ---   *   ---
# deps

];


# ---   *   ---   *   ---

  Readonly my $CLOSE_GUARDS=>q[
# ---   *   ---   *   ---
# snek is awful :c

];

# ---   *   ---   *   ---

sub boiler_open($class,$fname,%O) {

  state $FROM_RE=qr{from}sxm;

  my $s=$OPEN_GUARDS;
  $O{define}//=[];

  for my $path(@{$O{include}}) {

    # format as from X import Y
    if(is_arrayref($path)) {

      my ($src,@flist)=@$path;

      map {$ARG="  $ARG"} @flist;
      $path="from $src import (\n".(
        join ",\n",@flist

      )."\n\n)";

    # format as import X
    } else {
      $path="import $path";

    };

  };

  $s.=q[$:iter (path=>$O{include})
  "$path;\n"

;>

# ---   *   ---   *   ---
# ROM

$:iter (

  name=>$O{define_keys},
  value=>$O{define_values},

) "$name=$value;\n"

;>

# ---   *   ---   *   ---

];

  my $define_keys=
    array_keys($O{define});

  my $define_values=
    array_values($O{define});

# ---   *   ---   *   ---

  Peso::Ipret::pesc(

    \$s,

    fname=>$fname,
    note=>Emit::Std::note($O{author},q[#]),

    include=>$O{include},

    define_keys=>$define_keys,
    define_values=>$define_values,

  );

  return $s;

};

sub boiler_close($class,$fname,%O) {
  return $CLOSE_GUARDS;

};

# ---   *   ---   *   ---

sub shwlbind($fname,$soname,$libs_ref) {

  my %symtab=%{
    Shb7::soregen($soname,$libs_ref)

  };

  my $objects=Shb7::sofetch(\%symtab);

# ---   *   ---   *   ---

my $code=q[

class $:soname;>X:

;>

  @classmethod
  def nit():

    self=cdll.LoadLibrary(
      ARPATH+'/lib/lib$:soname;>.so'

    );

$:iter (

  name=>[@$O{names}],
  rtype=>[@$O{rtypes}],
  arg_types=>[@$O{arg_types}],

)

"    self.$x0=self.__getattr__".
"('$name');\n".

"    self.$x0.restype=$rtype;\n".
"    self.$x0.argtypes=$arg_types;\n\n"

;>

    return self;

# ---   *   ---   *   ---

lib$:soname;>=$:soname;>X.nit();

$:iter (

  name=>[@$O{names}],
  rtype=>[@$O{rtypes}],
  args=>[@$O{args}],
  arg_boiler=>[@$O{arg_boiler}],

)

"def $name($args):\n".
"  $arg_boiler;\n".
"  $:soname;>X.$name($args);\n\n"


;>

];

# ---   *   ---   *   ---

names
rtypes
args
arg_types
arg_boiler

# ---   *   ---   *   ---

  Peso::Ipret::pesc(

    \$code,

    soname=>$soname,

    names=>\@names,
    rtypes=>\@rtypes,

    args=>\@args,
    arg_types=>\@arg_types,
    arg_boiler=>\@arg_boiler,

  );

  return $code;

};

# ---   *   ---   *   ---
1; # ret


