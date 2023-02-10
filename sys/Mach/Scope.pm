#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH SCOPE
# namespace::sym in C++
# namespace_sym in C ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::Scope;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::IO;

  use Tree;
  use Tree::Grammar;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub new($class,%O) {

  # defaults
  $O{sep}=qr{::}x;

  my $tree_f = Tree->new_frame();
  my $self   = bless {

    tree  => $tree_f->nit(undef,'non'),
    sep   => $O{sep},

    order => [],
    path  => [],

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# announciation of existance

sub decl($self,$o,@path) {

  my $order = $self->{order};
  my $out   = $self->{tree}->force_get(@path);

  push @$order,\@path;

  # set and give
  $$out=$o;
  return $out

};

# ---   *   ---   *   ---
# ^for tree nodes
# use to find branches

sub decl_branch($self,$o,@path) {

  throw_invalid_branchref($o,@path)
  if ! Tree::Grammar->is_valid($o);

  return $self->decl($o,@path,q[$branch]);

};

# ---   *   ---   *   ---
# ^errme

sub throw_invalid_branchref($o,@path) {

  my $path=join q[/],@path;

  errout(

    q[Object at <%s> is not a ].
    q[Tree::Grammar instance but a %s],

    args => [$path,ref $o],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# assigment without order

sub asg($self,$o,@path) {

  my $out = $self->{tree}->get(@path);
  $$out   = $o;

  return $out;

};

# ---   *   ---   *   ---
# ^retrieve ptr

sub rget($self,@path) {
  my $o=$self->{tree}->get(@path);
  return $o;

};

# ---   *   ---   *   ---
# ^retrieve value

sub get($self,@path) {
  my $o=$self->{tree}->get(@path);
  return $$o;

};

# ---   *   ---   *   ---
# returns existance of path

sub has($self,@path) {
  my $out=$self->{tree}->has(@path);
  return $out;

};

# ---   *   ---   *   ---
# find across namespaces

sub search($self,$name,@path) {

  my $out;

  @path = $self->search_nc($name,@path);
  $out  = $self->has(@path);

  Tree::throw_bad_fetch(@path,$name)
  if ! $out;

  return $out;

};

# ---   *   ---   *   ---
# ^no errchk

sub search_nc($self,$name,@path) {

  @path=@{$self->{path}}
  if ! @path;

  my $tree = $self->{tree};
  my @alt  = split $self->{sep},$name;

  while(@path) {
    last if $self->has(@path,@alt);
    pop @path;

  };

  return (@path,@alt);

};

# ---   *   ---   *   ---
# conditionally dereference
# the "condition" being existance of value

sub cderef($self,$fet,$vref,@path) {

  my @rpath = $self->search_nc($$vref,@path);

  my $valid = $self->has(@rpath);
  my $fn    = ($fet) ? \&rget : \&get;

  $$vref    = $fn->($self,@rpath) if $valid;

  return $valid;

};

# ---   *   ---   *   ---
# set/get current path

sub path($self,@set) {

  if(@set) {
    $self->{path}=\@set;

  };

  return @{$self->{path}};

};

# ---   *   ---   *   ---
# ^go back a step

sub ret($self,$n=1) {

  my $out  = $NULLSTR;
  my $path = $self->{path};

  throw_nonret() if @$path<$n;

  # go back N steps
  map {$out=shift @$path} 0..$n-1;
  return $out;

};

# ---   *   ---   *   ---
# ^errme

sub throw_nonret() {

  errout(

    q[Attempted ret from non],

    args => [],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# debug out

sub prich($self,%O) {

  # defaults
  $O{errout}//=0;

  # select
  my $fh=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  # build me
  my $out=$NULLSTR;

  for my $key(keys %$self) {

    my $value=$self->{$key};

    if(Tree->is_valid($value)) {
      $value->prich();

    } else {
      $out.=sprintf "%-24s $value\n",$key;

    };

  };

  say {$fh} $out;

};

# ---   *   ---   *   ---
1; # ret
