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

  use lib $ENV{'ARPATH'}.'/lib/hacks/';

  use parent 'lyfil';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib';
  use style;
  use arstd;

  use Filter::Util::Call;

# ---   *   ---   *   ---
# global state

  my $TABLE={};
  my $PARENS_RE=shwl::delm(q[(],q[)]);

# ---   *   ---   *   ---

sub code_emit {

  my ($self)=@_;

  for my $fn(@{$self->{data}}) {

    my $str=shwl::STRINGS->{$fn};

    if(!($str=~ $TABLE->{re})) {
      next;

    };

    my $symname=${^CAPTURE[0]};
    my $sbl=$TABLE->{$symname};

# ---   *   ---   *   ---
# fetch args

    my @args=();
    if($str=~ m/$PARENS_RE/s) {
      @args=split m/,/,$+{body};

    };

# ---   *   ---   *   ---
# expand symbol and insert

    my $code=$sbl->paste(@args);
    $str=~ s/${symname}$PARENS_RE/$code/;

    shwl::STRINGS->{$fn}=$str;

# ---   *   ---   *   ---

  };

};

# ---   *   ---   *   ---

sub import {

  my ($pkg,$fname,$lineno)=(caller);
  my $self=lyfil::nit($fname,$lineno);

  if($self!=NULL) {
    $TABLE=shwl::getlibs();
    filter_add($self);

  };

print {*STDERR} $TABLE->{re}."\n";

};

# ---   *   ---   *   ---

sub unimport {
  filter_del();

};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;

  my ($pkg,$fname,$lineno)=(caller);
  my $status=filter_read();

  $self->logline(\$_);

  my $matches=shwl::cut(
    \$self->{chain}->[0]->{raw},

    "INLINE",

    $TABLE->{re},

  );

  push @{$self->{data}},@$matches;
  return $status;

};

# ---   *   ---   *   ---
1; # ret
