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
# lib,

# ---   *   ---   *   ---
# deps

package Emit::C;
  use v5.42.0;
  use strict;
  use warnings;

  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_hashref);
  use Type qw(sizeof typefet);
  use Type::C;

  use Arstd::String qw(cat);
  use Arstd::Array qw(nkeys nvalues);

  use lib "$ENV{ARPATH}/lib/";
  use parent 'Emit::Std';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# open boiler template

sub open_guards($class,$fname) {
  return join "\n",(
    "#ifndef __${fname}_H__",
    "#define __${fname}_H__",

    "#ifdef __cplusplus",
    'extern "C" {',
    "#endif",

    "\n"
  );
};


# ---   *   ---   *   ---
# ^close boiler template

sub close_guards($class,$fname) {
  return (
    "#ifdef __cplusplus",
    "};\n",
    "#endif",
    "#endif // __${fname}_H__",

    "\n"
  );
};


# ---   *   ---   *   ---
# header guards

sub boiler_open($class,$fname,%O) {
  $fname=uc $fname;

  # array as hash
  my $defi = 0;
  my @defk = nkeys($O{def});
  my @defv = nvalues($O{def});

  # add guards?
  my $guards=($O{guards})
    ? $class->open_guards($fname)
    : null
    ;

  # open boilerpaste
  my $s=(
    $class->note($O{author},q[//])
  . "\n$guards"

  . "// ---   *   ---   *   ---\n"
  . "// deps\n\n"

  . (join "\n",map {
      "  #include $ARG\n"

    } @{$O{inc}})

  . "\n\n"

  . "// ---   *   ---   *   ---\n"
  . "// ROM\n\n"

  . (join "\n",map {
      my $name  = $ARG;
      my $value = $defv[$defi++];

      "  #define $name $value\n";

    } @defk) . "\n\n"

  . "// ---   *   ---   *   ---\n"

  );


  # ^back to perl
  # give boilerpaste
  return $s;
};


# ---   *   ---   *   ---
# ^endof

sub boiler_close($class,$fname,%O) {
  $fname=uc $fname;

  my $guards=($O{guards})
    ? $class->close_guards($fname)
    : null
    ;

  # close boilerpaste
  my $s=(
    "// ---   *   ---   *   ---\n"
  . "\n$guards"
  );

  # ^back to perl
  # give boilerpaste
  return $s;
};


# ---   *   ---   *   ---
# turn list of args into string

sub arglist_str($class,$args,%O) {
  # defaults
  $O{nl}//=0;

  my $out=null;
  if($O{nl}) {
    $out=(
      "\n  "
    . (join ",\n  ",@$args)

    . "\n\n"

    );

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

  my $s=(
    "$O{rtype} $name($O{args}) "
  . "{\n$code\n\n};\n\n"
  );

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
  $O{class}   //= null;

  my $args=$class->arglist_str(
    $O{args},
    nl=>$O{args_nl}

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
  my @names = nkeys(\@vars);

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
  my $body=join ',',@items;
  return ($type eq 'enum')
    ? "$type {\n$body,$name\n};\n"
    : "$type ${name}[]={\n$body\n};\n"
    ;

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
  my $body=cat map {
    $class->switch_case($ARG,$O{$ARG})

  } keys %O;

  return "switch($x) {\n$body\n};\n";
};


# ---   *   ---   *   ---
# generates struc from peso type

sub struc_decl($class,$type) {
  $type=typefet $type
  if ! is_hashref $type;

  my $out="struct $type->{name} {\n";


  map {
    my ($ctype,$name)=@$ARG;
    $out .= "  $ctype $name;\n";

  } Type::xlate_struc(C=>$type);


  $out="$out};\n";

  return ($class ne 'Type::Cpp')
    ? "${out}typedef struct "
    . "$type->{name} $type->{name};"

    : $out
    ;
};


# ---   *   ---   *   ---
1; # ret
