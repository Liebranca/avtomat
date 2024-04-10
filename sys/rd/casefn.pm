#!/usr/bin/perl
# ---   *   ---   *   ---
# RD CASEFN
# Keyword-F maker
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::casefn;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get sub or die

sub fetch($class,$main,$name) {


  # get name is defined
  no strict 'refs';

  my %tab   = %{"$class\::"};
  my @valid = grep {
    defined &{$tab{$ARG}};

  } keys %tab;

  my ($have) = grep {$ARG eq $name} @valid;


  # ^validate
  $main->perr(

    "[ctl]:%s function '%s' "
  . "not implemented",

    args=>['case',$name],

  ) if ! defined $have;


  # give coderef
  $have=\&$have;
  return $have;

};

# ---   *   ---   *   ---
# replace node in hierarchy

sub repl($self,$data,$dst,$src) {

  $src=argproc($self,$data,$src);
  $dst=argproc($self,$data,$dst);

  $dst->repl($src);

  return;

};

# ---   *   ---   *   ---
# replace node with children

sub flatten($self,$data,$dst,$depth=0) {

  $dst=argproc($self,$data,$dst);

  map {

    my $anchor=$dst;

    $anchor=$anchor->{leaves}->[0]
    while @{$anchor->{leaves}};

    $anchor->{parent}->flatten_branch()
    if $anchor->{parent};


  } 1..$depth;

  $dst->deep_repl($dst->{leaves}->[0]);
  return;

};

# ---   *   ---   *   ---
# declares that a given sequence
# of tokens should mutate to
# a given call!

sub invoke($self,$data,@args) {

  shift @args;
  my $fn=pop @args;

  @args=map{argproc($self,$data,$ARG)} @args;
  $data->{-invoke}={

    fn   => $fn,
    sig  => [map {qr"^\[.$ARG\]"} @args],

    data => $data,

  };

  return;

};

# ---   *   ---   *   ---
# procs an argument

sub argproc($self,$data,$arg) {

  if(! index $arg,'.') {
    $arg=substr $arg,1,length($arg)-1;
    $arg=$data->{$arg};

  } elsif(Tree->is_valid($arg)) {
    return $arg;

  } else {

    my $main = $self->{main};
    my $tab  = {
      branch=>$main->{branch},

    };

    $arg=(exists $tab->{$arg})
      ? $tab->{$arg}
      : $arg
      ;

  };

  return $arg;

};

# ---   *   ---   *   ---
1; # ret
