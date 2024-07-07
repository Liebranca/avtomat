#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET:BINDER
# Oh, the blood that binds us...
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::binder;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Arstd::PM;
  use Arstd::WLog;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  subpkg=>[qw(
    ipret::binder::asm

  )],

  hier=>[CMD=>'proc'],

};

# ---   *   ---   *   ---
# imports sub-packages

sub new($class) {
  cloadi @{$class->subpkg};
  my $self=bless {},$class;

  return $self;

};

# ---   *   ---   *   ---
# ^retrive method

sub fetch($self,$name) {


  # result cached?
  return $self->{$name}
  if exists $self->{$name};


  # if F is found with this path,
  # then use that as-is
  my $class = ref $self;
  my $fn    = \&$name;

  # ^else lookup sub-packages!
  if(! defined &$fn) {

    for my $pkg($class,@{$self->subpkg}) {

      $fn="$pkg\::$name";
      $fn=\&$fn;

      last if defined &$fn;

    };

  };


  # ^validate
  $WLog->err(

    "could not find method [errtag]:%s",

    args => [$name],

    from => $class,
    lvl  => $AR_FATAL,

  ) if ! defined &$fn;


  # cache and give
  $self->{$name}=$fn;
  return $fn;

};

# ---   *   ---   *   ---
1; # ret
