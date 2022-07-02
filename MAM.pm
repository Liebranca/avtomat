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

  use Cwd qw(abs_path);

  use lib $ENV{'ARPATH'}.'/lib/hacks/';

  use parent 'lyfil';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;
  use cli;

  use Filter::Util::Call;

# ---   *   ---   *   ---
# ROM

  use constant OPTIONS=>[
    ['no_comments','-nc','--no_comments'],
    ['make_deps','-md','--make_deps'],

  ];

# ---   *   ---   *   ---
# global state

  my $SETTINGS={};

# ---   *   ---   *   ---

sub import {

  my @opts=@_;

  $SETTINGS=cli::nit(@{&OPTIONS});
  $SETTINGS->take(@opts);

  my ($pkg,$fname,$lineno)=(caller);
print "$fname\n";
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

# ---   *   ---   *   ---
# emit dependency files

    if($SETTINGS->{make_deps}!=NULL) {

      my $deps=shwl::DEPS_STR;
      my $re=abs_path(glob(q{~}));

      $re=qr{$re};
      $deps.="$self->{fname}\n";

      for my $path(values %INC) {
        if($path=~ $re) {
          $deps.=$path.q{ };

        };

      };

      $deps.=shwl::DEPS_STR;
      print $deps;

    };

# ---   *   ---   *   ---

  };

  return $status;

};

# ---   *   ---   *   ---
1; # ret
