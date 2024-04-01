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

  our $VERSION = v0.00.2;#a
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
  my $defval  = undef;


  # have default value?
  my $opera=$l1->is_opera($argname);

  # ^yep
  if(defined $opera && $opera eq '=') {

    ($argname,$defval)=map {

      my $out=$nd->{leaves}->[$ARG];

      (! @{$out->{leaves}})
        ? $out->{value}
        : $out
        ;

    } 0..1;

  };


  return {

    id     => $argname,
    type   => 'sym',

    defval => $defval,

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
  my $have = undef;


  # have list?
  if(defined $l1->is_list($key)) {
    return map {$self->argex($ARG)} @nest;

  # have [list]?
  } elsif(defined ($have=$l1->is_opera($key))
    && $have eq '['

  ) {

    # validate
    $main->perr(
      "Multiple identifiers for list arg"

    ) if 1 < @{$lv->{leaves}};

    my $branch=$lv->{leaves}->[0];

    return {

      id     => $branch->leaf_value(0),
      defval => undef,

      type   => 'qlist',

    };


  # ^have operator tree?
  } elsif(defined $have) {

    return {

      id     => $lv,
      defval => undef,

      type   => 'opera',

    };


  # have sub-branch?
  } elsif(defined $l1->is_branch($key)) {

    return

      map {$self->argex($ARG)}
      map {@{$ARG->{leaves}}} @nest;


  # have command?
  } elsif(defined ($have=$l1->is_cmd($key))) {

    if(! $lv->{escaped}) {
      my $l2=$main->{l2};
      $l2->recurse($lv);

      return $lv->{vref};

    } else {
      return {id=>$lv,defval=>undef};

    };


  # have single token!
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
1; # ret
