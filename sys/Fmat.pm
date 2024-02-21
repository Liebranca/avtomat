#!/usr/bin/perl
# ---   *   ---   *   ---
# FMAT
# Printing tasks that don't
# fit somewhere else
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Fmat;

  use v5.36.0;
  use strict;
  use warnings;

  use Perl::Tidy;
  use Readonly;

  use B qw(svref_2object);
  use Carp;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Arstd::String;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    codename
    fatdump

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.6;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# GBL

  my $Cache={
    walked=>{},

  };

# ---   *   ---   *   ---
# messes up formatting

sub tidyup($sref,$nofilt=1) {

  my $out=$NULLSTR;


  # we have to wrap to 54 columns ourselves
  # because perltidy cant get its effn
  # sheeeit together
  Arstd::String::linewrap(\$out,54);

  # ^there, doing your job for you
  Perl::Tidy::perltidy(
    source=>$sref,
    destination=>\$out,
    argv=>[qw(

      -q

      -cb -nbl -sot -sct
      -blbc=1 -blbcl=*
      -mbl=1

      -l=54 -i=2

    )],

  );


  if(! $nofilt) {
    $out=~ s/^(\s*\{)\s*/\n$1 /sgm;
    $out=~ s/(\}|\]|\));(?:\n|$)/\n\n$1;\n/sgm;

  };

  return $out;

};

# ---   *   ---   *   ---
# value already seen?

sub recursing($value) {

  return 1 if $Cache->{walked}->{$value};
  $Cache->{walked}->{$value}=1;

  return 0;

};

# ---   *   ---   *   ---
# deconstruct value

sub polydump($vref,$blessed=undef) {

  # idex into this array
  # based on value type
  state $tab=[

    \&valuedump,
    \&arraydump,
    \&deepdump,
    \&codedump,

  ];

  # value already seen?
  return $vref if recursing $vref;

  # corner case: compiled regexes
  return "'$$vref'" if is_qreref($vref);


  # map type to idex
  my $idex=
    (is_arrayref($$vref))
  | (is_hashref($$vref)*2)
  | (is_coderef($$vref)*3)
  ;

  # ^corner case: blessed ones ;>
  if(! $idex && $$vref && $blessed) {
    my $mod =! int($$vref=~ qr{=ARRAY});
    $idex=is_blessref($$vref)*(1+$mod);

  };


  # need for recursion?
  my $rec=($blessed && $blessed == 2)
    ? $blessed
    : undef
    ;


  # select F from table
  my $f=$tab->[$idex];

  # ^give string to print
  return ($idex)
    ? $f->($$vref,$rec)
    : $f->($vref,$rec)
    ;

};

# ---   *   ---   *   ---
# ^ice for hashes

sub deepdump($h,$blessed=undef) {

  return $h if recursing $h;


  '{' . ( join q[,],

    Arstd::Array::nmap(

      deepfilter($h,$blessed),
      sub ($kref,$vref) {"'$$kref' => $$vref"},

      'kv'

    ),

  ) . '}'

};

# ---   *   ---   *   ---
# ^print hashes and objects last

sub deepfilter($h,$blessed=undef) {[

  ( map  {$ARG=>polydump(\$h->{$ARG},$blessed)}
    grep {nref $h->{$ARG}}
    keys %$h

  ),

  ( map  {$ARG=>polydump(\$h->{$ARG},$blessed)}
    grep {! nref $h->{$ARG}}
    keys %$h

  )

]};

# ---   *   ---   *   ---
# ice for arrays

sub arraydump($ar,$blessed=undef) {

  return $ar if recursing $ar;


  '[' . ( join q[,],
    map {polydump(\$ARG,$blessed)} @$ar

  ) . ']';

};

# ---   *   ---   *   ---
# ^single value

sub valuedump($vref,$blessed=undef) {
  (defined $$vref) ? "'$$vref'" : 'undef';

};

# ---   *   ---   *   ---
# ^placeholder for coderefs

sub codedump($vref,$blessed=undef) {
  return '\&' . codename($vref);

};

# ---   *   ---   *   ---
# ^crux

sub fatdump($vref,%O) {

  # defaults
  $O{blessed} //= 0;
  $O{recurse} //= 0;
  $O{errout}  //= 0;

  # ^make setting apply recursively
  $O{blessed}=($O{recurse})
    ? $O{blessed} * 2
    : $O{blessed} * 1
    ;

  # ^clear the cache
  $Cache={};


  # get repr for vref
  my $s=(join ",\n",map {
    map {$ARG} polydump($ARG,$O{blessed})

  } $vref ) . q[;];

  # select
  my $fh=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  say {$fh} tidyup(\$s,0);
  say {$fh} $NULLSTR;

};

# ---   *   ---   *   ---
# gets name of coderef
#
# should be in Arstd::PM
# but that would complicate
# the dependency chain

sub codename($ref) {
  return svref_2object($ref)->GV->NAME;

};

# ---   *   ---   *   ---
1; # ret
