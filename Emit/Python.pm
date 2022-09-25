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

  Readonly my $OPEN_GUARDS=>

q[#!/usr/bin/python
$:note;>

# ---   *   ---   *   ---
# get system stuff

import os,sys;

ARPATH:str=os.getenv('ARPATH');
if(ARPATH+'/lib/' not in sys.path):
  sys.path.append(ARPATH+'/lib/');

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

  for my $path(@{$O{include}}) {

    # format as from X import Y
    if(is_arrayref($path)) {

      my ($src,@flist)=@$path;

      # lone asterisk
      if($flist[0] eq '*') {
        $path="from $src import *";

      # actual file list
      } else {
        map {$ARG="  $ARG"} @flist;
        $path="from $src import (\n".(
          join ",\n",@flist

        )."\n\n)";

      };

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

  name=>[array_keys($O{define})],
  value=>[array_values($O{define})],

) "$name=$value;\n"

;>

# ---   *   ---   *   ---

];

# ---   *   ---   *   ---

  Peso::Ipret::pesc(

    \$s,

    fname=>$fname,
    note=>Emit::Std::note($O{author},q[#]),

    include=>$O{include},
    define=>$O{define},

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

my $code=q{

class $:soname;>X:

  @staticmethod
  def nit():

    self=cdll.LoadLibrary(
      ARPATH+'/lib/lib$:soname;>.so'

    );

$:nitpaste;>

    return self;

# ---   *   ---   *   ---

lib$:soname;>=$:soname;>X.nit();
$:calpaste;>

};

# ---   *   ---   *   ---

  my $nitpaste=$NULLSTR;
  my @calpaste=();

  my (

    @names,
    @rtypes,

    @args,
    @arg_types,
    @arg_boiler,

  );

  for my $o(keys %$objects) {
    my @OB=@{$objects->{$o}};

    while(@OB) {

      my ($fn_name,$rtype,@ar)=@{
        shift @OB

      };

      my @ar_t=array_values(\@ar);
      my @ar_n=array_keys(\@ar);

      my $arg_names=join ',',@ar_n;
      my $arg_types;

      if($ar_t[0] eq 'pe_void') {
        $arg_types=$NULLSTR;

      } else {
        $arg_types=join ',',@ar_t;

      };

$nitpaste.=

"    self.$fn_name=self.__getattr__".
"('$fn_name');\n".

"    self.$fn_name.restype=$rtype;\n".
"    self.$fn_name.argtypes=[$arg_types];\n\n"

;

# ---   *   ---   *   ---
# type """transform""" calls
#
# actually a patch for how terrible
# python and it's abstractions are

      my $boiler=$NULLSTR;

      while(@ar_n && @ar_t) {

        my $n=shift @ar_n;
        my $t=shift @ar_t;

# ---   *   ---   *   ---
# strings are char arrays
#
# the conception of them as something else
# is entirely born out of high-level delusion
#
# it's only at and for this level that
# we even have to make this differentiation

        if(

            ($t=~ m[_str])
        && !($t=~ m[_ptr])

        ) {

          $boiler.="  $n=mcstr($t,$n);\n";

# ---   *   ---   *   ---
# again, purely conceptual

        } elsif(

            ($t=~ m[_str])
        &&  ($t=~ m[_ptr])

        ) {

          my $t2=$t;
          $t=~ s[_ptr$][];

          my $xform="[mcstr($t2,v) for v in $n]";

          $boiler.="  $n=mcstar($t,$xform);\n";

# ---   *   ---   *   ---
# if your arrays are not arrays under the hood,
# then your language has a serious problem

        } elsif(($t=~ m[_ptr])) {
          $boiler.="  $n=mcstar($t,$n);\n";

        };

# ---   *   ---   *   ---
# save the """transforms""" for this function

      };

push @calpaste,

"def $fn_name($arg_names):\n".$boiler.
"  return lib\$:soname;>.$fn_name($arg_names);\n\n"

;

    };

  };

# ---   *   ---   *   ---
# expand the code with the provided data

  Peso::Ipret::pesc(

    \$code,

    soname=>$soname,
    nitpaste=>$nitpaste,
    calpaste=>(join "\n",@calpaste),

  );

  return $code;

};

# ---   *   ---   *   ---
1; # ret
