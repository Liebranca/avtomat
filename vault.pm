#!/usr/bin/perl
# ---   *   ---   *   ---
# VAULT
# Keeps your stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package vault;

  use v5.36.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;
  use shb7;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# global state

  our $modules={};

# ---   *   ---   *   ---

INIT {

#  $modules=shb7::walk('avtomat',-r=>1);

};

# ---   *   ---   *   ---

sub import(@args) {

  shift @args;

  my ($pkg,$fname,$line)=caller;
  if($pkg eq 'main') {goto TAIL};

  my $mod=shb7::module_of(
    abs_path($fname)

  );

  $modules->{$mod}//={};
  $modules->{$mod}->{$pkg}=1;

# ---   *   ---   *   ---

TAIL:
  return;

};

# ---   *   ---   *   ---

sub modsum() {

#  for my $name(keys %$modules) {
#    my $table=shb7::walk($name,-r=>1);
#    $modules->{$name}=$table;
#
#  };

};

END {modsum()};

# ---   *   ---   *   ---

#  my $f=shb7::shpath(abs_path(
#    './hacks/shwl.pm'
#
#  ));
#
#  my @keys=split m[/],$f;
#
#  my $o=$table;
#
#  while(@keys) {
#
#    my $key=shift @keys;
#
#    if(exists $o->[0]->{$key}) {
#      $o=$o->[0]->{$key};
#
#    };
#
#  };
#
#  return $o;

# ---   *   ---   *   ---
1; # ret
