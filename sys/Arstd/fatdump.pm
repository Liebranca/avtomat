#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD FATDUMP
# Also known as fatdumpo
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::fatdump;
  use v5.42.0;
  use strict;
  use warnings;

  use Perl::Tidy;
  use B qw(svref_2object);

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use AR sys=>qw(
    use Chk::(
      is_hashref
      is_arrayref
      is_coderef
      is_qreref
      is_blessref
      is_nref
    );

    lis Arstd::Array::(nmap);
    use Arstd::Fmat::(tidyup);
    lis Arstd::IO::(procin procout);
    use Arstd::PM::(codename);
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(fatdump);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# RAM

  my $Cache={walked=>{}};


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
  my $tab=[
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
  my $idex=(
    (is_arrayref($$vref))
  | (is_hashref($$vref)*2)
  | (is_coderef($$vref)*3)
  );

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
  return '{' . join(q[,],array_nmap(
    deepfilter($h,$blessed),
    sub ($kref,$vref) {"'$$kref' => $$vref"},

    'kv'

  )) . '}';
};


# ---   *   ---   *   ---
# ^print hashes and objects last

sub deepfilter($h,$blessed=undef) {
  return [(
    map  {$ARG=>polydump(\$h->{$ARG},$blessed)}
    grep {is_nref $h->{$ARG}}
    keys %$h

  ) => (
    map  {$ARG=>polydump(\$h->{$ARG},$blessed)}
    grep {! is_nref $h->{$ARG}}
    keys %$h

  )];
};


# ---   *   ---   *   ---
# ice for arrays

sub arraydump($ar,$blessed=undef) {
  return $ar if recursing $ar;
  return '[' . join(q[,],map {
    polydump(\$ARG,$blessed)

  } @$ar) . ']';
};


# ---   *   ---   *   ---
# ^single value

sub valuedump($vref,$blessed=undef) {
  return (defined $$vref)
    ? "'$$vref'"
    : 'undef'
    ;
};


# ---   *   ---   *   ---
# ^placeholder for coderefs

sub codedump($vref,$blessed=undef) {
  return '\&' . codename($vref,1);
};


# ---   *   ---   *   ---
# ^crux

sub fatdump($vref,%O) {
  # I/O defaults
  my $out=io_procin(\%O);

  # defaults
  $O{blessed} //= 0;
  $O{recurse} //= 0;

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


  # ^give repr
  push @$out,tidyup(\$s,filter=>1),"\n\n";
  return io_procout(\%O);
};


# ---   *   ---   *   ---
1; # ret
