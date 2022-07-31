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
  use Arstd;

  use Data::Dumper;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(fatdump);

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.4;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---

sub tidyup($sref) {

  my $out=$NULLSTR;

  Perl::Tidy::perltidy(
    source=>$sref,
    destination=>\$out,
    argv=>[qw(

      -l=54 -i=2 -cb -nbl -sot -sct
      -blbc=1 -blbcl=*
      -mbl=1

    )],

  );

  $out=~ s/^(\s*[\}\]\)][;,]?\n)/$1\n/sgm;
  $out=~ s/^(\s*\{)\s*/\n$1 /sgm;

  return $out;

};

# ---   *   ---   *   ---

sub fatdump($data) {
  my $s=Dumper($data);
  return tidyup(\$s);

};

# ---   *   ---   *   ---
1; # ret
