#!/usr/bin/perl
# ---   *   ---   *   ---
# GRAMMAR
# Base class for all
# lps-derived parsers
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Tree::Grammar;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $OR={
    name=>q[|]

  };

  sub Frame_Vars($class) { return {

    -ns     => {'$decl:order'=>[]},
    -cns    => [],

    -npass  => 0,
    -passes => [],

  }};

# ---   *   ---   *   ---
# global state

  our $Top;

# ---   *   ---   *   ---
# returns our $Top for calling package

sub get_top($class) {

  no strict 'refs';
  return ${"$class\::Top"};

};

sub set_top($class,$name) {

  no strict 'refs';

  my $f=Tree::Grammar->get_frame();
  ${"$class\::Top"}=$f->nit(value=>$name);

  return ${"$class\::Top"};

};

# ---   *   ---   *   ---
# decon string using rules

sub parse($class,$prog,%O) {

  # defaults
  $O{-r}//=0;

  my $self=bless {
    frame => $class->new_frame(),

  },$class;

  unshift @{
    $self->{frame}->{-passes}

  },$NULLSTR;

  my $gram=$class->get_top();
  my $tree=$gram->parse($self,$prog);

  $class->run($tree) if $O{-r};

  return $tree;

};

# ---   *   ---   *   ---
# ^runs registered ctx subs on
# whole parse tree

sub run($class,$tree) {

  my @nodes=($tree);
  $tree->{ctx}->{frame}->{-npass}++;

  while(@nodes) {

    my $nd=shift @nodes;

    $nd->{fn}->($nd)
    if $nd->{fn} ne $NOOP;

    unshift @nodes,@{$nd->{leaves}};

  };

};

# ---   *   ---   *   ---
# ensure chain slot per pass

sub cnbreak($class,$X,$dom,$name) {

  my $vars   = $class->Frame_Vars();
  my @passes = (@{$vars->{-passes}});

  my $i=0;
  $X->{chain}//=[];

  my $valid  = !is_coderef($name);

  for my $ext(@passes) {

    # get context
    my $r=(undef,\($X->{chain}->[$i]));
    my $f=codefind($dom,$name.$ext)
    if $valid;

    # use fptr if no override provided
    $$r=(defined $f) ? $f : $$r;
    $$r//=$NOOP;

    $i++;

  };

};

# ---   *   ---   *   ---
# branch function search

sub fnbreak($class,$X) {

  my ($name,$dom)=($X->{fn},$X->{dom});

  $name //= $X->{name};
  $dom  //= 'Tree::Grammar';

  goto SKIP if is_qre($name);

  # get sub matching name
  $X->{fn}=codefind($dom,$name)
  if !is_coderef($name);

  # generate chain
  $class->cnbreak($X,$dom,$name);

SKIP:

  # ^default if none found
  $X->{fn}//=$NOOP;

  return;

};

# ---   *   ---   *   ---
# generates branches from descriptor array

sub mkrules($class,@rules) {

  # shorten subclass name
  my $name    = $class;
  $name       =~ s[^Grammar\::][];

  # build root
  my $top     = $class->set_top($name);
  my @anchors = ($top);

  # walk
  while(@rules) {

    my $value=shift @rules;

    # go back one step in hierarchy
    if($value eq 0) {
      pop @anchors;
      next;

    };

    # get parent node
    my $anchor=$anchors[-1];

    $class->fnbreak($value);

    # instantiate
    my $nd=$anchor->init(

      $value->{name},

      fn    => $value->{fn},

      opt   => $value->{opt},
      greed => $value->{greed},

      chain => $value->{chain},

    );

    # recurse
    if($value->{chld}) {

      unshift @rules,@{$value->{chld}},0;
      push    @anchors,$nd;

    };

  };

};

# ---   *   ---   *   ---
# add object to specific namespace

sub ns_decl($self,$o,@path) {

  my $ns    = $self->{frame}->{-ns};
  my $order = $ns->{'$decl:order'};

  push @$order,\@path;
  ns_asg($self,$o,@path);

};

# ---   *   ---   *   ---
# gets reference from path

sub ns_fetch($self,@path) {

  my $ns  = $self->{frame}->{-ns};
  my $dst = \$ns;

  for my $key(@path) {

    next if !$key;

    ${$dst}->{$key}//={};
    $dst=\(${$dst}->{$key});

  };

  return $dst;

};

# ---   *   ---   *   ---
# ^same, assigment without order

sub ns_asg($self,$o,@path) {

  my $dst = $self->ns_fetch(@path);
  $$dst   = $o;

};

# ---   *   ---   *   ---
# ^fetches value

sub ns_get($self,@path) {

  my $o=$self->ns_fetch(@path);
  return $$o;

};

# ---   *   ---   *   ---
# dirty and quick backwards evaluating
# to find across namespaces

sub ns_search($self,$name,$sep,@path) {

  my @out   = ();
  my @cm    = ();

  my @alt   = split $sep,$name;
  my $oname = pop @alt;

  for(

    my ($i,$j)=($#path,$#alt);

    $j>=0 && $i>=0;
    $i--,$j--


  ) {

    my $a=\$path[$i];
    my $b=\$alt[$j];

    $$a=$$b if $$a ne $$b;

  };

  @out=(@path,$oname);

  return @out;

};

# ---   *   ---   *   ---
1; # ret
