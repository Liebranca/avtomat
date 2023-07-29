#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD PM
# Perl module utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::PM;

  use v5.36.0;
  use strict;
  use warnings;

  use Devel::Peek;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::IO;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    submerge

    autoload_prologue
    throw_bad_autoload

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get subs of module

sub subsof($class) {

  no strict 'refs';

  my %tab   = %{"$class\::"};
  my @names = grep {
    defined &{$tab{$ARG}}

  } keys %tab;

  return map {$ARG=>$class} @names;

};

# ---   *   ---   *   ---
# ^give subs of multiple modules,
# popping any duplicates

sub subsof_dupop(@classes) {
  return map {subsof($ARG)} @classes;

};

# ---   *   ---   *   ---
# ^subroutines of modules
# if they don't exist in main

sub subsof_merge($main,@classes) {

  my %subs = subsof($main);
  my %ext  = subsof_dupop(@classes);

  my @add  = grep {! exists $subs{$ARG}} keys %ext;

  return map {$ARG=>$ext{$ARG}} @add;

};

# ---   *   ---   *   ---
# ^actually add them to main

sub submerge($classes,%O) {

  if($O{xdeps}) {

    my %filt = map {$ARG=>1} @$classes;
    my @deps = grep {
      ! exists $filt{$ARG}

    } array_depsof(@$classes);

    my $re=Lang::eiths(\@deps,bwrap=>1);
    $O{modex}=qr{^$re$};

  };

  # defaults
  $O{subex} //= $NO_MATCH;
  $O{modex} //= $NO_MATCH;

  my ($main)=caller;

  # get [symbol=>module]
  my %subs=subsof_merge($main,@$classes);

  # ^filter out excluded subs
  # and subs from excluded mods
  my @filt=grep {

    my $ref = "$subs{$ARG}\::$ARG";
    my $gv  = Devel::Peek::CvGV(\&$ref);

    ! ($ARG=~ $O{subex})
  &&! (*$gv{PACKAGE}=~ $O{modex})

  } keys %subs;

  # ^bat-xfer
  map {add_symbol(
    "$main\::$ARG",
    "$subs{$ARG}\::$ARG"

  )} @filt;

  return @filt;

};

# ---   *   ---   *   ---
# adds symbol from one
# namespace to another

sub add_symbol($dst,$src) {
  no strict 'refs';
  *{$dst}=*{$src};

};

# ---   *   ---   *   ---
# get immediate deps of module

sub depsof($class,$fmain=undef) {

  $class=~ s[::][/]sxmg;

  my $re    = qr{^$class\.pm};

  my @keys  = grep {$ARG=~ $re} keys %INC;
  my @files = map {$INC{$ARG}} @keys;

  return map {depsof_file($ARG)} @files;

};

# ---   *   ---   *   ---
# ^bat

sub array_depsof(@classes) {

  my %tab=map {
    map {$ARG=>1} depsof($ARG)

  } @classes;

  return keys %tab;

};

# ---   *   ---   *   ---
# ^get 'use [name]' directives in file

sub depsof_file($fname) {

  state $re=qr{

  \n\s* use \s+
  (?<name> [^\s]+) ;

  }x;

  my @out  = ();
  my $body = orc($fname);

  while($body=~ s[$re][]) {
    push @out,$+{name};

  };

  return @out;

};

# ---   *   ---   *   ---
# autoload helpers

sub autoload_prologue($kref) {

  state $re=qr{^.*::};
  $$kref=~ s[$re][];

  return $$kref ne 'DESTROY';

};

sub throw_bad_autoload($pkg,$key) {

  errout(

    q['%s' has no autoload for '%s'],

    args => [$pkg,$key],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
1; # ret
