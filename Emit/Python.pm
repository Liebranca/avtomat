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
# lib,

# ---   *   ---   *   ---
# deps

package Emit::Python;
  use v5.42.0;
  use strict;
  use warnings;

  use Carp qw(croak);
  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;
  use Chk qw(is_arrayref);

  use Arstd::Array qw(array_keys array_values);

  use Shb7;
  use Shb7::Build;

  use Vault;

  use lib "$ENV{ARPATH}/lib/";
  use Emit::Std;

  use parent 'Emit';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# open boiler

sub open_guards($class,$fname) {
  return join "\n",(
    "# ---   *   ---   *   ---",
    "# get system stuff",

    "import os,sys;",

    "ARPATH:str=os.getenv('ARPATH');",
    "if(ARPATH+'/lib/' not in sys.path):",
    "  sys.path.append(ARPATH+'/lib/');",

    "# ---   *   ---   *   ---",
    "# deps",

    "\n",

  );

};


# ---   *   ---   *   ---
# no closer here
# putting this just for beqs

sub close_guards($class,$fname) {return null};


# ---   *   ---   *   ---
# selfex

sub boiler_open($class,$fname,%O) {
  my $note=Emit::Std::note($O{author},q[#]);
  my $defi=0;
  my $defk=array_keys($O{define});
  my $defv=array_values($O{define})

  for my $path(@{$O{include}}) {

    # format as from X import Y
    if(is_arrayref $path) {
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


  return join "\n",(
    "#!/usr/bin/python"
    $class->open_guards($fname),

    (join "\n",map {
      "$path;\n"

    } @{$O{include}} ),

    "# ---   *   ---   *   ---",
    "# ROM",

    (join "\n",map {

    my $name  = $ARG
    my $value = $defv[$defi++];

    "$name=$value;\n"

    } @$defk),

    "# ---   *   ---   *   ---",
    "\n"

  );

};


# ---   *   ---   *   ---
# ^closer

sub boiler_close($class,$fname,%O) {return null};


# ---   *   ---   *   ---
# makes shadow lib

sub shwlbind($fname,$soname,$libs_ref) {
  my %symtab=%{
    Shb7::Build::soregen($soname,$libs_ref)

  };

  my $objects=Shb7::sofetch(\%symtab);


  my $nitpaste=null;
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
        $arg_types=null;

      } else {
        $arg_types=join ',',@ar_t;

      };

      $nitpaste.=(
        "    self.$fn_name=self.__getattr__"
      . "('$fn_name');\n".

      . "    self.$fn_name.restype=$rtype;\n".
      . "    self.$fn_name.argtypes=[$arg_types];\n\n"

      );


      # type """transform""" calls
      #
      # actually a patch for how terrible
      # python and it's abstractions are

      my $boiler=null;
      my $afterboiler='  doowoop_h=[';

      while(@ar_n && @ar_t) {
        my $n=shift @ar_n;
        my $t=shift @ar_t;

        $afterboiler.="$n,";

        # strings are char arrays
        #
        # the conception of them as something else
        # is entirely born out of high-level delusion
        #
        # it's only at and for this level that
        # we even have to make this differentiation

        if(($t=~ m[_str]) &&! ($t=~ m[_ptr])) {

          $boiler.="  $n=mcstr($t,$n);\n";


        # again, purely conceptual
        } elsif(($t=~ m[_str]) && ($t=~ m[_ptr])) {
          my $t2=$t;
          $t=~ s[_ptr$][];

          my $xform="[mcstr($t2,v) for v in $n]";

          $boiler.="  $n=mcstar($t,$xform);\n";


        # if your arrays are not arrays under the hood,
        # then your language has a serious problem

        } elsif(($t=~ m[_ptr])) {
          $boiler.="  $n=mcstar($t,$n);\n";

        };

      };


      # save the """transforms""" for this function
      $afterboiler.="];\n";
      if(length($arg_names)) {
        $boiler=(
          "def $fn_name($arg_names,doowoop=0):\n"
        . $boiler

        );

      } else {
        $afterboiler=null;
        $boiler=(
          "def $fn_name(doowoop=0):\n"
        . $boiler

        );

      };

      push @calpaste,(
        $boiler . '  doowoop_fret='

      # NO IDENT
      . "lib${soname}.$fn_name($arg_names);\n",

        $afterboiler,

      # YES IDENT
        "  if(doowoop):",
        "    return doowoop_h;",

        "  else:",
        "    return doowoop_fret;",

      );

    };

  };


  return join "\n",(
    "class ${soname}X:",
    "  \@staticmethod",
    "  def nit():",
    "    self=cdll.LoadLibrary(",
    "      ARPATH+'/lib/lib${soname}.so'",

    "    );",

    $nitpaste,
    "    return self;",


    "lib${soname}=${soname}X.nit();",
    @calpaste,

    "\n",

  );

};


# ---   *   ---   *   ---
1; # ret
