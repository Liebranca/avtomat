#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7
# Shell utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb
# ---   *   ---   *   ---

# deps
package Shb7;

  use v5.36.0;
  use strict;
  use warnings;

  use Storable;
  use Readonly;

  use Cwd qw(abs_path getcwd);

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::String;
  use Arstd::Array;
  use Arstd::Hash;
  use Arstd::Path;
  use Arstd::IO;

  use Shb7::Path;
  use Shb7::Find;
  use Shb7::Build;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# loads a file if available
# else regenerates it from a sub

sub load_cache($name,$dst,$call,@args) {

  my ($pkg,$fname,$line)=(caller);
  my $path=cache($pkg.q{::}.$name);

  my $out={};

  if(moo($path,abs_path($fname))) {

    print {*STDERR}

      'updated ',"\e[32;1m",
      shpath($path),

      "\e[0m\n"

    ;

    $out=$call->(@args);
    store($out,$path);

  } else {
    $out=retrieve($path);

  };

  $$dst=$out;

};

# ---   *   ---   *   ---

sub sofetch($symtab) {

  my $tab={};

  for my $o(keys %{$symtab->{objects}}) {

    my $obj=$symtab->{objects}->{$o};
    my $funcs=$obj->{functions};

    my $ref=$tab->{$o}=[];

    for my $fn_name(keys %$funcs) {

      my $fn=$funcs->{$fn_name};
      my $rtype=$fn->{type};

      push @$ref,[$fn_name,$rtype,@{$fn->{args}}];

    };

  };

  return $tab;

};

# ---   *   ---   *   ---
1; # ret
