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

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::IO;
  use Arstd::PM;
  use Arstd::Re;

  use Tree;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.7;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $BRANCH_PATH=>q[$branch];

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{sep}=$DCOLON_RE;

  my $tree_f = Tree->new_frame();
  my $self   = bless {

    tree    => $tree_f->new(undef,'non'),
    sep     => $O{sep},

    order   => [],
    path    => [],

    recache => {},

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
# ^retraction of it

sub rm($self,@path) {

  my $nd=$self->{tree}->haslv(@path)
  or Tree::throw_bad_fetch(@path);

  $nd->discard();

};

# ---   *   ---   *   ---
# ^for tree nodes
# use to find branches

sub decl_branch($self,$o,@path) {

  throw_invalid_branchref($o,@path)
  if ! Tree->is_valid($o);

  return $self->decl($o,@path,$BRANCH_PATH);

};

# ---   *   ---   *   ---
# ^errme

sub throw_invalid_branchref($o,@path) {

  my $path=join q[/],@path;

  errout(

    q[Data at <%s> is not a ].
    q[Tree but a %s],

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
  return $self->{tree}->has(@path);

};

# ---   *   ---   *   ---
# ^return path itself

sub haslv($self,@path) {
  return $self->{tree}->haslv(@path);

};

# ---   *   ---   *   ---
# ^branch wraps

sub asg_branch($self,$o,@path) {

  throw_invalid_branchref($o,@path)
  if ! Tree::Grammar->is_valid($o);


  return $self->asg($o,@path,$BRANCH_PATH);

};

# ---   *   ---   *   ---
# ^getters

sub rget_branch($self,@path) {
  return $self->rget(@path,$BRANCH_PATH);

};

sub get_branch($self,@path) {
  return $self->get(@path,$BRANCH_PATH);

};

sub has_branch($self,@path) {
  return $self->has(@path,$BRANCH_PATH);

};

sub haslv_branch($self,@path) {
  return $self->haslv(@path,$BRANCH_PATH);

};

# ---   *   ---   *   ---
# branch removal

sub rm_branch($self,@path) {
  $self->rm(@path,$BRANCH_PATH);

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

  # cat name to path
  my $tree = $self->{tree};
  my @alt  = split $self->{sep},$name;


  # ^pop from namespace until
  # symbol is found
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
  my $fn    = ($fet) ? 'rget' : 'get';

  $$vref    = $self->$fn(@rpath) if $valid;

  return $valid;

};

# ---   *   ---   *   ---
# ^user friendly wraps
# looks within current scope

sub getvar($self,$name,%O) {

  # defaults
  $O{as_ptr} //= 0;
  $O{path}   //= [];


  # perform lookup
  my $out  = $name;
  my $have = $self->cderef(
    $O{as_ptr},
    \$out,

    @{$O{path}}

  );


  # ^give on success
  return ($have)
    ? $out
    : undef
    ;

};

# ---   *   ---   *   ---
# ^branch wraps

sub search_branch($self,$name,@path) {
  return $self->search(
    $name,@path,$BRANCH_PATH

  );

};

sub search_nc_branch($self,$name,@path) {
  return $self->search_nc(
    $name,@path,$BRANCH_PATH

  );

};

sub cderef_branch($self,$fet,$vref,@path) {

  $$vref.="\::$BRANCH_PATH";

  return $self->cderef(
    $fet,$vref,@path

  );

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
# get current branch

sub curblk($self) {

  return $self->get(
    $self->path(),
    $BRANCH_PATH

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
# compile-time defines
#
# used to check for parse-time
# macro expansions
#
# a horrible idea in theory,
# with alternatives being even
# worse in practice

# ---   *   ---   *   ---
# generate regex for matching
# against defs in current path

sub cdef_recache($self) {

  my @path   = $self->cdef_path();
  my $branch = $self->{tree}->fetch(path=>\@path);

  my @names  = grep {
    $ARG ne '~:recache'

  } $branch->branch_values();

  my $o      = re_eiths(

    \@names,
    opscape => 1,

  );

  if(! $self->cdef_has('~:recache')) {
    $self->cdef_decl($NO_MATCH,'~:recache');

  };

  $self->cdef_call('asg',['~:recache'],$o);

};

# ---   *   ---   *   ---
# ^fetch

sub cdef_re($self) {

  if(! $self->cdef_has('~:recache')) {
    $self->cdef_decl($NO_MATCH,'~:recache');

  };

  return $self->cdef_get('~:recache');

};

# ---   *   ---   *   ---
# clear all definitions

sub cdef_clear($self) {
  state $re=qr{^\$CDEF$};
  $self->{tree}->sweep($re);

};

# ---   *   ---   *   ---
# get F corresponding to type
# of reference passed for expansion

sub poly_crepl($self,$vref) {

  state $tab=[

    'value_crepl',
    'array_crepl',
    'deep_crepl',

  ];

  my $idex=
    (is_arrayref($$vref))
  | (is_hashref($$vref)*2)
  ;

  my $f=$tab->[$idex];

  return ($idex)
    ? $self->$f($$vref)
    : $self->$f($vref)
    ;

};

# ---   *   ---   *   ---
# replace value for macro expansion
# if value matches cdef_re

sub value_crepl($self,$vref) {

  my $re=$self->cdef_re();
  return 0 if $re eq $NO_MATCH;


  if($$vref=~ m[($re)]) {

    my $s=$self->cdef_get($1);
    $$vref=~ s[$re][$s];

    return int($$vref=~ $re);

  };

  return 0;

};

# ---   *   ---   *   ---
# ^for all levels of a hash

sub deep_crepl($self,$o) {
  map {$self->poly_crepl(\$o->{$ARG})} keys %$o;

};

# ---   *   ---   *   ---
# ^arrayrefs

sub array_crepl($self,$ar) {
  map {$self->poly_crepl(\$ARG)} @$ar;

};

# ---   *   ---   *   ---
# ^lists

sub crepl($self,@refs) {
  map {$self->poly_crepl($ARG)} @refs;

};

# ---   *   ---   *   ---
# boilerplate for cdef wraps

sub cdef_path($self) {
  return @{$self->{path}},q[$CDEF];

};

sub cdef_call($self,$f,$name,@args) {
  my @path=($self->cdef_path(),@$name);
  return $self->$f(@args,@path);

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$self->cdef_call] => q[$self,$o,@name],

  map {["cdef_$ARG" => "'$ARG'," . q[\@name,$o]]}
  qw  (decl decl_branch asg)

);

# ---   *   ---   *   ---
# ^same idea, different signature

subwraps(

  q[$self->cdef_call] => q[$self,@name],

  map {["cdef_$ARG" => "'$ARG'," . q[\@name]]}
  qw  (rget get rm has)

);

# ---   *   ---   *   ---
# ^continued...

subwraps(

  q[$self->cdef_call] => q[$self,@name],

  map {["cdef_$ARG" => "'$ARG'," . q[[],\@name]]}
  qw  (search search_nc)

);

# ---   *   ---   *   ---
# ^wrap single

sub cdef_cderef($self,$fet,$vref,@name) {
  $self->cdef_call('cderef',\@name,$fet,$vref);

};

# ---   *   ---   *   ---
1; # ret
