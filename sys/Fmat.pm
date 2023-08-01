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

  use Carp;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::String;

  use Data::Dumper;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(fatdump);

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.5;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---

sub tidyup($sref) {

  my $out=$NULLSTR;

  # we have to wrap to 54 columns ourselves
  # because perltidy cant get its effn
  # sheeeit together
  linewrap($sref,54);

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

  $out=~ s/^(\s*\{)\s*/\n$1 /sgm;
  $out=~ s/(\}|\]|\));(?:\n|$)/\n\n$1;\n/sgm;

  return $out;

};

# ---   *   ---   *   ---
# deconstruct value

sub polydump($vref,$blessed=undef) {

  state $tab=[

    \&valuedump,
    \&arraydump,
    \&deepdump,

  ];

  my $idex=
    (is_arrayref($$vref))
  | (is_hashref($$vref)*2)
  ;

  if(! $idex && $blessed) {
    $idex=is_blessref($$vref)*2;

  };

  my $f=$tab->[$idex];

  return ($idex)
    ? $f->($$vref)
    : $f->($vref)
    ;

};

# ---   *   ---   *   ---
# ^ice for hashes

sub deepdump($h) {

  '{' . ( join q[,],

    map {

      "$ARG => "
    . polydump(\$h->{$ARG})

    } keys %$h

  ) . '}';

};

# ---   *   ---   *   ---
# ^ice for arrays

sub arraydump($ar) {

  '[' . ( join q[,],
    map {polydump(\$ARG)} @$ar

  ) . ']';

};

# ---   *   ---   *   ---
# ^single value

sub valuedump($vref) {
  (defined $$vref) ? $$vref : 'undef';

};

# ---   *   ---   *   ---
# ^crux

sub fatdump($vref,%O) {

  # defaults
  $O{blessed} //= 0;
  $O{errout}  //= 0;

  my $s=(join ",\n",map {
    map {$ARG} polydump($ARG,$O{blessed})

  } $vref ) . q[;];

  # select
  my $fh=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  say {$fh} tidyup(\$s);
  say {$fh} $NULLSTR;

};

# ---   *   ---   *   ---
1; # ret
