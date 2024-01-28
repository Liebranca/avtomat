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
  use Module::Load;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Re;
  use Arstd::IO;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    subsof
    submerge

    codeof
    argsof

    autoload_prologue
    throw_bad_autoload

    beqwraps
    get_static
    cload

    fvars

    IMP

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.7;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get subs of module
# unfiltered version for internal use

sub _subsof($class) {

  no strict 'refs';

  my %tab   = %{"$class\::"};
  my @names = grep {
    defined &{$tab{$ARG}};

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

    my $re=re_eiths(\@deps,bwrap=>1);
    $O->{modex}=qr{^$re$};

  };

  # defaults
  $O->{subex} //= qr{^(?:throw_|Frame_Vars$)};
  $O->{modex} //= $NO_MATCH;
  $O->{subok} //= $ANY_MATCH;

};

# ---   *   ---   *   ---
# ^filter out excluded subs
# and subs from excluded mods

sub subsof_filter($subs,%O) {

  return grep {

    my $ref = "$subs->{$ARG}\::$ARG";
    my $gv  = Devel::Peek::CvGV(\&$ref);

  # accept entry if:
      ($ARG=~ $O{subok})

  &&! ($ARG=~ $O{subex})
  &&! (*$gv{PACKAGE}=~ $O{modex})

  ;

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

  $O{main}  //= caller;
  $O{xdeps} //= 1;

  my $main=$O{main};
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

sub add_scalar($dst,$src) {

  no strict 'refs';

  add_symbol($dst,$src);
  ${$dst}=${$dst};

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

sub argsof($pkg,$name=undef) {

  state $decl=qr{
    my \s+ (?<var> \W\w+) \s* =

  }x;

  state $doblk=qr{

    do \s* \{

    (?<blk> [^\{\}]+ | (?R)*)

    \};

  }x;

  my @out=();


  # avoid re-deparse if body
  # passed in pkg
  my $body=(defined $name)
    ? codeof($pkg,$name)
    : $pkg
    ;

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
# get codestr for sub

sub codeof($pkg,$name=undef) {

  my $fn=$pkg;

  if(defined $name) {
    $fn=join q[::],$pkg,$name;
    $fn=\&$fn;

  };

  my $body = B::Deparse->new->coderef2text($fn);

  return $body;

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
# fetch global our $Var

sub get_static($class,$name) {

  if(length ref $class) {
    $class=ref $class;

  };

  no strict 'refs';
  return ${"$class\::$name"};

};

# ---   *   ---   *   ---
# conditionally load packages
# if they're not already loaded

sub cload(@pkg) {

  no strict 'refs';

  map {
    load $ARG if ! is_loaded($ARG);

  } @pkg;

};

# ---   *   ---   *   ---
# ^checks INC

sub is_loaded($pkg) {

  my $fname=  $pkg;
     $fname=~ s[$DCOLON_RE][/]g;

  return grep {
    $ARG eq "$fname.pm"

  } keys %INC;

};

# ---   *   ---   *   ---
# makes local fvars hook

sub fvars($classes,%O) {

  my $dst  = caller;
  my %have = _subsof($dst);

  no strict 'refs';

  $classes=(! is_arrayref($classes))
    ? [$classes]
    : $classes
    ;


  *{"$dst\::Frame_Vars"}=sub ($class) { return {

    (map {
      %{$ARG->Frame_Vars()}

    } @$classes),

    %O,

  }} if ! exists $have{Frame_Vars};

};

# ---   *   ---   *   ---
# AR/IMP:
#
# * runs 'crux' with provided
#   input if ran as executable
#
# * if imported as a module,
#   execute some subroutine

sub IMP($class,$on_use,$on_exe,@req) {

  # imported as exec via arperl
  if(defined $req[0]
  &&  $req[0] eq '*crux'

  ) {

    shift @req;
    return $on_exe->($class,@req);


  # imported as module via use
  } else {
    return $on_use->($class,(caller 1)[0],@req);

  };

};

# ---   *   ---   *   ---
1; # ret
