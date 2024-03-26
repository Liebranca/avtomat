#!/usr/bin/perl
# ---   *   ---   *   ---
# MACRO
# The original copy-paste
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmdlib::macro;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# makes new command!

cmdsub macro => q(
  sym,opt_vlist,curly

) => q{


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $mc    = $main->{mc};
  my $scope = $mc->{scope};
  my @path  = @{$mc->{path}};


  # unpack
  my ($name,$args,$body)=
    @{$branch->{leaves}};


  # redecl guard
  $name=$l1->is_sym($name->{value});
  push @path,macro=>$name;

  $main->throw_redecl(macro=>$name)
  if $scope->has(@path);


  # ^collapse optional
  if(! defined $body) {
    $body=$args;
    $args=undef;

  };


  # have arguments?
  $args=($args)
    ? $self->argread($args,$body)
    : []
    ;


  # make table for ipret
  my $cmdtab={

    name   => $name,
    body   => $body,

    args   => $args,

  };

  $main->{cmdlib}->new(

    lis => $name,
    pkg => __PACKAGE__,

    fn  => undef,

  );

  # ^save to current namespace and remove branch
  $scope->force_set($cmdtab,@path);
  $branch->discard();

  $main->{lx}->load_CMD(1);


  return;

};

# ---   *   ---   *   ---
# hammer time!

cmdsub stop => q(opt_sym) => q{

  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $lx   = $main->{lx};
  my $list = $lx->stages;


  # name of stage says *when* to stop!
  my $stage=$branch->{leaves}->[0];

  if($stage) {
    $stage=$l1->is_sym($stage->{value});

  };

  $stage //= $list->[0];


  # are we there yet? ;>
  if($stage eq $list->[$main->{stage}]) {
    $main->{tree}->prich();
    $main->perr('STOP');

  # ^nope, wait
  } else {
    $branch->{vref}=$stage;
    $branch->clear();

  };

};

# ---   *   ---   *   ---
# dbout (placeholder)

cmdsub echo => q(qlist) => q{
  say 'NYI: ECHOVARS';

};

# ---   *   ---   *   ---
1; # ret
