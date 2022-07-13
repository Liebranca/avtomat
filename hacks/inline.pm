#!/usr/bin/perl
# ---   *   ---   *   ---
# INLINE
# None of you dared
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

package inline;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';

  use parent 'lyfil';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib';
  use style;
  use arstd;

#  use Filter::Util::Call;

# ---   *   ---   *   ---
# ROM

  Readonly our $CREATE_SCOPE=>0x01;

# ---   *   ---   *   ---
# global state

  my $TABLE={};
  my $PARENS_RE=shwl::delm(q[(],q[)]);

# ---   *   ---   *   ---

sub decl_args($rd,@args) {

  my $nd_frame=$rd->{program}->{node};
  my $block=$rd->{curblk};

  my $branch=$block->{tree};
  my $id=$block->{name};
  my $i=0;

  for my $argname(@args) {

    $argname=~ s/^([\$\@\%]+)//sg;
    my $original=$argname;

    if(!defined ${^CAPTURE[0]}) {

      arstd::errout(
        "Can't match sigil for var %s\n",

        args=>[$original],
        lvl=>$FATAL,

      );

    };

# ---   *   ---   *   ---

    my $sigil=${^CAPTURE[0]};

    my $nd=$nd_frame->nit($branch,
      "my \$inlined_${id}_$argname=".
      ":__ARG_${i}__:;",

      unshift_leaves=>1,

    );

    $i++;
  };

};

# ---   *   ---   *   ---

sub repl_args($order,@args) {

  my %tab;
  my @order=@$order;

# ---   *   ---   *   ---

  for my $node(@args) {
    my $key=$node->{value};

# ---   *   ---   *   ---

    if(!exists $tab{$key}) {
      $tab{$key}=[$node];

# ---   *   ---   *   ---

    } else {
      push @{$tab{$key}},$node;

    };

  };

# ---   *   ---   *   ---

  my $i=0;
  for my $key(@order) {

    goto TAIL if !exists$tab{$key};
    my @nodes=@{$tab{$key}};

# ---   *   ---   *   ---

    for my $node(@nodes) {
      $node->{value}=":__ARG_${i}__:";

    };

# ---   *   ---   *   ---

TAIL:
    $i++;

  };

};

# ---   *   ---   *   ---

sub rename_args($rd,@args) {

  my $block=$rd->{curblk};
  my $id=$block->{name};

  for my $mention(@args) {

    my $key=$mention->{value};

    $key=~ s/^([\$\@\%]+)//sg;

    if(!defined ${^CAPTURE[0]}) {
      die "Can't match sigil";

    };

    my $sigil=${^CAPTURE[0]};

    $mention->{value}=$sigil.
      "inlined_${id}_$key";

  };

};

# ---   *   ---   *   ---

#sub code_emit {
#
#  my ($self)=@_;
#
#  for my $fn(@{$self->{data}}) {
#
#    my $str=shwl::STRINGS->{$fn};
#
#    if(!($str=~ $TABLE->{re})) {
#      next;
#
#    };
#
#    my $symname=${^CAPTURE[0]};
#    my $sbl=$TABLE->{$symname};
#
## ---   *   ---   *   ---
## fetch args
#
#    my @args=();
#    if($str=~ m/($PARENS_RE)/s) {
#      @args=split m/,/,${^CAPTURE[0]};
#
#    };
#
## ---   *   ---   *   ---
## expand symbol and insert
#
#    my $code=$sbl->paste(@args);
#    $str=~ s/${symname}$PARENS_RE/$code/;
#
#    shwl::STRINGS->{$fn}=$str;
#
## ---   *   ---   *   ---
#
#  };
#
#};
#
## ---   *   ---   *   ---
#
#sub import {
#
#  my ($pkg,$fname,$lineno)=(caller);
#  my $self=lyfil::nit($fname,$lineno);
#
#  if($self!=$NULL) {
#    $TABLE=shwl::getlibs();
#    filter_add($self);
#
#  };
#
#};
#
## ---   *   ---   *   ---
#
#sub unimport {
#  filter_del();
#
#};
#
## ---   *   ---   *   ---
#
#sub filter {
#
#  my ($self)=@_;
#
#  my ($pkg,$fname,$lineno)=(caller);
#  my $status=filter_read();
#
#  $self->logline(\$_);
#
#  my $matches=shwl::cut(
#    \$self->{chain}->[0]->{raw},
#
#    "INLINE",
#
#    $TABLE->{re},
#
#  );
#
#  push @{$self->{data}},@$matches;
#  return $status;
#
#};

# ---   *   ---   *   ---
1; # ret
