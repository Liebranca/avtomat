#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:CMD ARGPROC
# Typechecked madness
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmd::argproc;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# parse argname(=value)?

sub argproc($self,$nd) {


  # assume already processed if
  # input is not a tree
  return $nd
  if ! Tree->is_valid($nd);


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # [name => default value]
  my $argname = $nd->{value};
  my $defv    = undef;


  # have default value?
  my $opera=$l1->xlate($argname);

  # ^yep
  if($opera && $opera->{spec} eq '=') {

    ($argname,$defv)=map {

      my $out=$nd->{leaves}->[$ARG];

      (! @{$out->{leaves}})
        ? $out->{value}
        : $out
        ;

    } 0..1;

  };


  return {

    id   => $argname,

    type => 'sym',
    defv => $defv,

  };

};

# ---   *   ---   *   ---
# expand token tree accto
# type of first token

sub argex($self,$lv) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # fstate
  my $key  = $lv->{value};
  my @nest = @{$lv->{leaves}};
  my $have = $l1->xlate($key);

  return $lv if ! $have;

  my $type=$have->{type};
  my $spec=$have->{spec};


  # have list?
  if($type eq 'LIST') {
    return map {$self->argex($ARG)} @nest;


  # have [list]?
  } elsif($type eq 'SCP' && $spec eq '[') {

    # validate
    $main->perr(
      "Multiple identifiers for list arg"

    ) if 1 < @{$lv->{leaves}};

    my $branch=$lv->{leaves}->[0];

    return {

      id   => $branch->leaf_value(0),
      defv => undef,

      type => 'qlist',

    };


  # ^have operator tree?
  } elsif($type eq 'OPR') {

    return {

      id   => $lv,
      defv => undef,

      type => 'opr',

    };


  # have expression?
  } elsif($type eq 'EXP') {

    return

      map {$self->argex($ARG)}
      map {@{$ARG->{leaves}}} @nest;


  # have command?
  } elsif($type eq 'CMD') {


    # solve NOW?
    if(! $lv->{escaped}) {
      my $l2=$main->{l2};
      $l2->recurse($lv);

      return $lv->{vref};

    # solve later!
    } else {

      return {

        id   => $lv,

        type => 'cmd',
        defv => undef,

      };

    };


  # have string?
  } elsif($type eq 'STR') {

    return {

      id   => $have->{data},

      type => 'str',
      defv => undef,

    };


  # have number?
  } elsif($type eq 'NUM') {

    return {

      id   => $spec,

      type => 'num',
      defv => undef,

    };


  # have symbol, leave it to argproc
  } else {
    return $lv;

  };

};

# ---   *   ---   *   ---
# proc branch leaf as a
# list of arguments

sub arglist($self,$branch,$idex=0) {


  # get leaf to proc
  my $lv=$branch->{leaves}->[$idex];
  return [] if ! $lv;

  # ^pluck and give
  ($lv)=$branch->pluck($lv);
  return $self->argex($lv);

};

# ---   *   ---   *   ---
# ^proc && pop N leaves

sub argtake($self,$branch,$len=1) {


  # give [name => value]
  return map {
    $self->argproc($ARG);


  # ^from expanded token tree
  } map {
    $self->arglist($branch)

  } 1..$len;

};

# ---   *   ---   *   ---
# consume argument nodes for command

sub argsume($self,$branch) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};
  my $tab   = $frame->{keytab};
  my $l2    = $main->{l2};


  # save current
  my $old=$l2->{branch};

  # attempt match
  my $key   = $self->{key};
  my $have  = $tab->match($key,$branch);

  $branch->{argsvref}=$have;


  # restore and give
  $l2->{branch}=$old;
  return;

};

# ---   *   ---   *   ---
1; # ret
