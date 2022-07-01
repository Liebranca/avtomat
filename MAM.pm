#!/usr/bin/perl
# ---   *   ---   *   ---
# MAM
# Filtered source emitter
#
# do not use in scripts;
# call it like so:
#
# perl -MMAM=[opts]
#
# ---   *   ---   *   ---
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

package MAM;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';

  use parent 'lyfil';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;
  use cli;

  use Filter::Util::Call;

  our $SETTINGS={};

# ---   *   ---   *   ---
# ROM

  use constant OPTIONS=>[
    ['keep_comments','-kc','--keep_comments'],

  ];

# ---   *   ---   *   ---

sub import {

  my @opts=@_;
  my $m=cli::nit(@{&OPTIONS});

  $m->take(@opts);

  my ($pkg,$fname,$lineno)=(caller);
  my $self=lyfil::nit($fname,$lineno);

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

  if(!$status) {
    $self->propagate();
    shwl::stitch(\$self->{chain}->[0]->{raw});

    $self->prich();

  };

  return $status;

};

# ---   *   ---   *   ---
1; # ret
