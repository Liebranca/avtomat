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

  use B::Deparse;
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

    subsof
    submerge

    argsof

    autoload_prologue
    throw_bad_autoload

    beqwraps

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get subs of module
# unfiltered version for internal use

sub _subsof($class) {

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
  return map {_subsof($ARG)} @classes;

};

# ---   *   ---   *   ---
# ^subroutines of modules
# if they don't exist in main

sub subsof_merge($main,@classes) {

  my %subs = _subsof($main);
  my %ext  = subsof_dupop(@classes);

  my @add  = grep {! exists $subs{$ARG}} keys %ext;

  return map {$ARG=>$ext{$ARG}} @add;

};

# ---   *   ---   *   ---
# initializes subroutine filters

sub subsof_filter_nit($classes,$O) {

  if($O->{xdeps}) {

    my %filt = map {$ARG=>1} @$classes;
    my @deps = grep {
      ! exists $filt{$ARG}

    } array_depsof(@$classes);

    my $re=Lang::eiths(\@deps,bwrap=>1);
    $O->{modex}=qr{^$re$};

  };

  # defaults
  $O->{subex} //= $NO_MATCH;
  $O->{modex} //= $NO_MATCH;

};

# ---   *   ---   *   ---
# ^filter out excluded subs
# and subs from excluded mods

sub subsof_filter($subs,%O) {

  return grep {

    my $ref = "$subs->{$ARG}\::$ARG";
    my $gv  = Devel::Peek::CvGV(\&$ref);

    ! ($ARG=~ $O{subex})
  &&! (*$gv{PACKAGE}=~ $O{modex})

  } keys %$subs;

};

# ---   *   ---   *   ---
# ^crux

sub subsof($classes,%O) {

  # defaults
  $O{main} //= caller;

  # proc options
  subsof_filter_nit($classes,\%O);

  # get [symbol=>module]
  my %subs=subsof_merge($O{main},@$classes);
  my @filt=subsof_filter(\%subs,%O);

  # ^apply filter to subs
  return map {
    $ARG => $subs{$ARG}

  } @filt;

};

# ---   *   ---   *   ---
# ^add filtered list of subs to main

sub submerge($classes,%O) {

  my $main=caller;
  my %subs=subsof($classes,%O,main=>$main);

  # ^bat-xfer
  map {add_symbol(
    "$main\::$ARG",
    "$subs{$ARG}\::$ARG"

  )} keys %subs;

  return %subs;

};

# ---   *   ---   *   ---
# adds symbol from one
# namespace to another

sub add_symbol($dst,$src) {
  no strict 'refs';
  *{$dst}=*{$src};

};

# ---   *   ---   *   ---
# akin to selective inheritance
# defines methods of attribute to wrap

sub beqwraps($attr,@names) {

  no strict 'refs';
  my $pkg=caller;

  map {

    my $name = $ARG;
    my $fn   = sub ($self,@args) {
      $self->{$attr}->$name(@args);

    };

    *{"$pkg\::$name"}=$fn;

  } @names;

};

# ---   *   ---   *   ---
# get arguments of subroutine
# by deparsing it's signature (!!)

sub argsof($pkg,$name) {

  state $decl=qr{
    my \s+ (?<var> \W\w+) \s* =

  }x;

  state $doblk=qr{

    do \s* \{

    (?<blk> [^\{\}]+ | (?R)*)

    \};

  }x;

  my @out  = ();

  # get codestr for sub
  my $fn   = join q[::],$pkg,$name;
  my $body = B::Deparse->new->coderef2text(\&$fn);
  my $blk  = $NULLSTR;

  # ^pop do {} block
  $body =~ s[$doblk][];
  $blk  =$+{blk};

  # notify of signature-less sub
  return -1 if ! $blk;

  # ^pop "var" from my var = ...
  while($blk=~ s[$decl][]) {
    push @out,$+{var};

  };

  return @out;

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

  return 0 if ($$kref=~ m[DESTROY$]);

  state $re=qr{^.*::};
  $$kref=~ s[$re][];

  return 1;

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
