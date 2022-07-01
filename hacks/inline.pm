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

  use Filter::Util::Call;
  our $TABLE={};

# ---   *   ---   *   ---

sub code_emit {

  my ($self)=@_;

  for my $fn(@{$self->{data}}) {

    my $str=shwl::STRINGS->{$fn};

    $str=~ $TABLE->{re};
    my $symname=${^CAPTURE[0]};
    my $sbl=$TABLE->{$symname};

# ---   *   ---   *   ---
# fetch args

    my @args=();
    my $args_re=shwl::ARGS_RE;
    if($str=~ m/$args_re/s) {
      @args=split m/,/,$+{arg};

    };

# ---   *   ---   *   ---
# expand symbol and insert

    my $code=$sbl->paste(@args);
    $str=~ s/${symname}$args_re/$code/;

    shwl::STRINGS->{$fn}=$str;

# ---   *   ---   *   ---

  };

};

# ---   *   ---   *   ---

sub import {

  my ($pkg,$fname,$lineno)=(caller);
  my $self=lyfil::nit($fname,$lineno);

  $TABLE=shwl::getlibs();
  filter_add($self);
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

  $self->logline($_);

  my $matches=shwl::cut(
    \$self->{chain}->[0]->{raw},

    "INLINE",

    $TABLE->{re}.shwl::ARGS_RE,

  );

  push @{$self->{data}},@$matches;
  return $status;

};

# ---   *   ---   *   ---
1; # ret
