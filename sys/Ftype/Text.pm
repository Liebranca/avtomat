#!/usr/bin/perl
# ---   *   ---   *   ---
# FTYPE TEXT
# Oh boi...
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text;
  use v5.42.0;
  use strict;
  use warnings;

  use Carp;
  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

  use Arstd::String qw();
  use Arstd::Re qw(
    re_eiths
    re_eaf
    re_posix_delim

  );

  use Arstd::Repl;
  use parent 'Ftype';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

St::vconst {

  name_re    => '\b[_A-Za-z][_A-Za-z0-9]*\b',
  uc_name_re => '\b[_A-Z][_A-Z0-9]*\b',
  lc_name_re => '\b[_a-z][_a-z0-9]*\b',

  fn_re => sub {
    my $name=$_[0]->name_re;
    return qr{$name\(};

  },

  pesc_re    => Arstd::Re->PESC_RE,
  num_re     => sub {return [
    Arstd::String->BINNUM_RE,
    Arstd::String->OCTNUM_RE,
    Arstd::String->DECNUM_RE,
    Arstd::String->HEXNUM_RE,

  ]},

  opr_re     => qr{[^[:alpha:][:space:]0-9_]},
  drfc_re    => sub {
    my $name=$_[0]->name_re;
    return qr{$name\s*(?:->|::|\.)\s*$name};

  },

  line_re    => qr{.+},
  blank_re   => qr{[[:space:]]+$},
  nblank_re  => qr{[^[:blank:]]+},

  shcmd_re   => re_posix_delim('`'),
  char_re    => re_posix_delim("'"),
  string_re  => re_posix_delim('"'),

  sigils_re  => qr{\\?[\$@%&]},

  dev0_re => re_eiths([qw(TODO NOTE)],bwrap=>1),
  dev1_re => re_eiths([qw(FIX BUG)],bwrap=>1),


  DEFAULT => {

    name        => null,

    com         => q[#],
    lcom        => q[#],

    hed         => 'N/A',
    ext         => null,
    mag         => null,

    highlight   => [],

    type        => [],
    specifier   => [],

    builtin     => [],
    intrinsic   => [],
    fctl        => [],

    directive   => [],
    resname     => [],

    preproc     => qr{$NO_MATCH}x,
    use_sigils  => {},

  },

};


# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # make ice
  $class->defnit(\%O);
  my $self=bless \%O,$class;

  # for replacing $:tag;> with
  # value of self->tag
  $self->{repl}=Arstd::Repl->new(
    pre  => 'PESC',
    inre => Arstd::Re->peso_escape,
    repv => sub {repv($self,@_)},

  );

  # ^right here
  $self->make_keyw_re();

  # comments...
  $self->{lcom}=re_eaf(
    $self->{lcom},
    lbeg    => 0,
    opscape => 0,

  ) if $self->{lcom};


  # notify super and give
  $class->register($self);
  return $self;

};


# ---   *   ---   *   ---
# convert keyword lists to hashes

sub make_keyw_re($self) {

  my @keyw_re=map {

    my $key = $ARG;
    my @ar  = @{$self->{$ARG}};
    my $out = {};

    # perform value substitution for
    # each sub-pattern
    map {
      $self->{repl}->proc(\$ARG);
      $out->{$ARG}=0;

    } @ar;

    # ^make composite
    my $keyw_re=(int %$out)
      ? re_eiths([keys %$out],bwrap=>1)
      : $NO_MATCH
      ;

    # ^write to ice and give
    $out->{-re}=$keyw_re;
    $self->{$key}=$out;

    $keyw_re

  } qw(
    type specifier builtin fctl
    intrinsic directive resname

  );


  # one regex to rule them all!
  $self->{keyword_re}=join '|',@keyw_re;
  $self->{keyword_re}=qr{$self->{keyword_re}};

  return;

};


# ---   *   ---   *   ---
# get $:value;> to put for replace

sub repv($self,$repl,$uid) {
  my $key   = $repl->{capt}->[$uid]->{body};
  my $value = $self->fet($key);

  croak "Bad key in peso escape: '$key'"
  if ! defined $value;

  return $value;

};


# ---   *   ---   *   ---
# fetch value

sub fet($self,$key) {
  return $self->{$key}
  if exists $self->{$key};

  return $self->$key
  if $self->can($key);

  $key="${key}_re";
  return $self->$key
  if $self->can($key);


  return undef;

};


# ---   *   ---   *   ---
1; # ret
