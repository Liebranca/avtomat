#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO MACH
# Low-level subset
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::mach;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;

  use Grammar 'dynamic';
#  use Grammar::peso::common;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_MACH);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $PE_MACH=>
    'Grammar::peso::mach';

  Readonly our $REGEX=>{};

# ---   *   ---   *   ---
# make dynamic grammar from mach ice

sub from_ice($class,$mach,$name,%O) {

  # defaults
  $O{dom}   //= $class;
  $O{rules} //= [];
  $O{core}  //= [];

  my $self=$class->dnew($name,dom=>$O{dom});

  # ^nit retab
  $self->{regex}={

    %$REGEX,
    ins=>$mach->{optab}->{re},

  };

  # ^nit rules
  map {$self->drule($ARG)} @{$O{rules}};
  $self->mkrules(@{$O{core}});

  return $self;

};

# ---   *   ---   *   ---
# test

use Mach;
use Fmat;

my $rules = ['%<T=T>'];
my $core  = [qw(T)];

my $mach  = Mach->new();

$PE_MACH->from_ice(

  $mach,'default',

  rules => $rules,
  core  => $core,

);

my $ice=$PE_MACH->parse(

  'T',

  mach => $mach,
  iced => 'default',

);

$ice->{p3}->prich();

# ---   *   ---   *   ---
1; # ret
