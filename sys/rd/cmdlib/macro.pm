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

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# makes new command!

cmdsub macro => q(
  bare,opt_vlist,curly

) => q{


  # get ctx
  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};
  my $scope = $mc->{scope};
  my $path  = $mc->{path};


  # unpack
  my ($name,$args,$body)=
    @{$branch->{leaves}};


  # redecl guard
  $name=$name->{value};
  $main->throw_redecl('user command'=>$name)
  if $scope->has(@$path,'UCMD',$name);


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

  # ^save to current namespace and remove branch
  $scope->decl($cmdtab,@$path,'UCMD',$name);
  $branch->discard();

  my $lx  = $main->{lx};
  my $CMD = $lx->load_CMD(1);

  use Fmat;
  fatdump(\$CMD);

  exit;

};

# ---   *   ---   *   ---
# hammer time!

cmdsub stop => q() => q{

  my $main=$self->{frame}->{main};

  $main->{tree}->prich();
  $main->perr('STOP');

};

# ---   *   ---   *   ---
# dbout (placeholder)

cmdsub echo => q(qlist) => q{
  say 'NYI: ECHOVARS';

};

# ---   *   ---   *   ---
1; # ret
