#!/usr/bin/perl
# ---   *   ---   *   ---
# RD PREPROCFN
# F-enn macros!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::preprocfn;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
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

  my ($have) = grep {
     $ARG =~ qr{^_?$name$}

  } @valid;


  if(! $have) {

    my $tab  = $main->{preproc}->{tab};
       $have = $tab->{$name}->{fn};

  };


  # ^validate
  $main->perr(

    "[ctl]:%s function '%s' "
  . "not implemented",

    args=>[$main->{preproc}->genesis,$name],

  ) if ! defined $have;


  # give coderef
  $have=\&$have if ! is_coderef $have;
  return $have;

};

# ---   *   ---   *   ---
# replace node in hierarchy

sub replace($self,$data,$dst,$src) {

  $dst=argproc($self,$data,$dst);
  $src=argproc($self,$data,$src);

  if(Tree->is_valid($src)) {
    $dst->repl($src);

  } else {
    $dst->{value}=$src;

  };

  return;

};

# ---   *   ---   *   ---
# adds new nodes at pos

sub insert($self,$data,$dst,@src) {

  $dst=argproc($self,$data,$dst);
  @src=map{argproc($self,$data,$ARG)} @src;


  my $idex=shift @src;

  map {

    (Tree->is_valid($ARG))
      ? $dst->insertlv($idex,$ARG)
      : $dst->insert($idex,$ARG)
      ;

  } @src;

  return;

};

# ---   *   ---   *   ---
# ^adds new node at end

sub _push($self,$data,$dst,@src) {

  $dst=argproc($self,$data,$dst);
  @src=map{argproc($self,$data,$ARG)} @src;


  map {
    (Tree->is_valid($ARG))
      ? $dst->pushlv($ARG)
      : $dst->inew($ARG)
      ;

  } @src;

  return;

};

# ---   *   ---   *   ---
# move branch to top!

sub merge($self,$data,$dst) {

  $dst = argproc($self,$data,$dst);
  $dst = $dst->discard();

  my $anchor = argproc($self,$data,'branch');
  my $root   = argproc($self,$data,'root');


  while($anchor->{parent} ne $root) {
    $anchor=$anchor->{parent};

  };

  my $idex=$anchor->{idex};

  ($dst)=$root->insertlv($idex+1,$dst);

  return $dst;

};

# ---   *   ---   *   ---
# ^merge and flatten ;>

sub mergef($self,$data,$dst,$depth=0) {

  $dst=merge($self,$data,$dst);
  flatten($self,$data,$dst,$depth);

  return;

};

# ---   *   ---   *   ---
# replace node with children

sub flatten($self,$data,$dst,$depth=0) {

  $dst=argproc($self,$data,$dst);
  $dst->flatten_tree(max_depth=>$depth);

  return;

};

# ---   *   ---   *   ---
# remove yourself!

sub discard($self,$data,$dst) {

  $dst=argproc($self,$data,$dst);
  $dst->discard();

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


  # get ctx
  my $main   = $self->{main};
  my $branch = $main->{branch};

  my $tab    = {

    branch => $branch,
    parent => $branch->{parent},
    last   => $branch->{leaves}->[-1],
    root   => $main->{tree},

  };


  # have attr name?
  if(! index $arg,'self.') {
    $arg=substr $arg,5,length($arg)-5;
    $arg=$data->{$arg};

  # have branch name?
  } elsif(! index $arg,'lv.') {
    $arg=substr $arg,3,length($arg)-3;
    $arg=$branch->branch_in(qr{$arg});

  # have reference?
  } elsif(exists $tab->{$arg}) {
    $arg=$tab->{$arg};

  };


  return $arg;

};

# ---   *   ---   *   ---
1; # ret
