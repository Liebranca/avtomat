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
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::PM;
  use v5.42.0;
  use strict;
  use warnings;

  use B qw(svref_2object);
  use Devel::Peek;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null no_match any_match);
  use Chk qw(is_arrayref);
  use Arstd::Re qw(eiths);
  use Arstd::Bin qw(orc);
  use Arstd::Path qw(to_pkg);
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(subwraps);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# give name of coderef

sub codename($ref,$full=0) {
  # get guts handle
  my $gv=svref_2object($ref)->GV;

  # ^skip fetching package name when
  # ^we don't care about it
  return $gv->NAME if ! $full;

  # fetch package name?
  my %cni  = reverse %INC;
  my $name = to_pkg $cni{$gv->FILE};

  # you think you're funny?!
  if(! length $name) {
    my $body=orc $gv->FILE;

    ($name)   = $body=~ qr{package ([^;]+);};
    ($name) //= 'main';

  };

  return "$name\::" . $gv->NAME;
};


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

    my $re=eiths(\@deps,bwrap=>1);
    $O->{modex}=qr{^$re$};

  };

  # defaults
  $O->{subex} //= qr{^(?:throw_|Frame_Vars$)};
  $O->{modex} //= no_match;
  $O->{subok} //= any_match;

  return;
};


# ---   *   ---   *   ---
# ^filter out excluded subs
# ^and subs from excluded mods

sub subsof_filter($subs,%O) {
  return grep {
    my $ref = "$subs->{$ARG}\::$ARG";
    my $gv  = Devel::Peek::CvGV(\&$ref);

  # accept entry if:
  (   ($ARG=~ $O{subok})

  &&! ($ARG=~ $O{subex})
  &&! (*$gv{PACKAGE}=~ $O{modex})

  );

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
  # defaults
  $O{main}  //= caller;
  $O{xdeps} //= 1;

  # get subroutines in classes
  my $main=$O{main};
  my %subs=subsof($classes,%O,main=>$main);

  # ^bat-xfer
  map { add_symbol(
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

  return;
};

sub add_scalar($dst,$src) {
  no strict 'refs';

  add_symbol($dst,$src);
  ${$dst}=${$dst};

  return;
};


# ---   *   ---   *   ---
# ^redefine symbol without warning

sub redef($old,$new) {
  no strict   'refs';
  no warnings 'redefine';

  *{$old}=$new;

  return;
};


# ---   *   ---   *   ---
# give first caller that
# doesn't match passed name

sub rcaller {
  # default to Arstd::PM ;>
  my $name   = $_[0];
     $name //= __PACKAGE__;

  # ^pop until another found
  my $i    = 1;
  my $pkg  = caller $i++;
     $pkg  = caller $i++

  while  $pkg eq $name && $i < 0x24;
  return $pkg;
};


# ---   *   ---   *   ---
# akin to selective inheritance
# defines methods of attribute to wrap

sub beqwraps($attr,@names) {
  no strict 'refs';
  my $pkg=rcaller;
  for(@names) {
    my $name = $ARG;
    my $fn   = sub ($self,@args) {
      $self->{$attr}->$name(@args);

    };

    *{"$pkg\::$name"}=$fn;

  };

  return;
};


# ---   *   ---   *   ---
# internal. makes wrappers!

sub mkwraps($pkg,$fn,$sig,@icebox) {
  no strict 'refs';
  for(@icebox) {
    # unpack
    my ($name,$args) = @$ARG;
    my $dst          = "$pkg\::$name";

    # generate wrapper
    my $src = "sub ($sig) {\n"
    . '  local *__ANON__ = ' . "'$dst';\n"
    . "  $fn($args);\n"

    . "};";

    my $wf=eval $src;


    # ^validate
    throw "BAD ICEF*CK: $dst\n\n$src\n"
    if ! defined $wf;

    # add to namespace
    *{$dst}=$wf;
  };

  use strict 'refs';
  return;
};


# ---   *   ---   *   ---
# ^icef*ck

sub subwraps($fn,$sig,@icebox) {
  my $pkg=rcaller;
  mkwraps($pkg,$fn,$sig,@icebox);

  return;
};


# ---   *   ---   *   ---
# ^indirect: make wrappers
# and add them to *another*
# package!

sub impwraps($dst,@args) {
  mkwraps($dst,@args);
  return;
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

  my $blk=null;

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

  my $body=St::deparse->coderef2text($fn);

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
  throw sprintf(
    "'%s' has no autoload for '%s'",
    $pkg,
    $key,

  );
};


# ---   *   ---   *   ---
# fetch global our $Var

sub get_static($class,$name) {
  $class=ref $class if length ref $class;

  no strict 'refs';
  return ${"$class\::$name"};
};


# ---   *   ---   *   ---
# makes local fvars hook

sub fvars($classes,%O) {
  my $dst  = caller;
  my %have = _subsof($dst);

  $classes=(! is_arrayref $classes)
    ? [$classes]
    : $classes
    ;

  no strict 'refs';
  *{"$dst\::Frame_Vars"}=sub ($class) { return {
    (map {
      %{$ARG->Frame_Vars()}

    } @$classes),

    %O,

  }} if ! exists $have{Frame_Vars};


  return;
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
  if(defined $req[0] && $req[0] eq '*crux') {
    shift @req;
    return $on_exe->($class,@req);

  };

  # imported as module via use
  return $on_use->($class,(caller 1)[0],@req);
};


# ---   *   ---   *   ---
1; # ret
