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

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null no_match);
  use Arstd::throw;
  use Arstd::stoi;
  use Arstd::Re;

  use Arstd::Repl;
  use parent 'Ftype';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.3a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub name_re    {'\b[_A-Za-z][_A-Za-z0-9]*\b'};
sub uc_name_re {'\b[_A-Z][_A-Z0-9]*\b'};
sub lc_name_re {'\b[_a-z][_a-z0-9]*\b'};

sub pesc_re    {Arstd::Re->PESC_RE};

sub fn_re($class) {
  my $name=$class->name_re();
  return qr{$name\(};
};

sub num_re {return [
  Arstd::stoi::binnum(),
  Arstd::stoi::octnum(),
  Arstd::stoi::decnum(),
  Arstd::stoi::hexnum(),
]};

sub opr_re {qr{[^[:alpha:][:space:]0-9_]}};

sub drfc_re($class) {
  my $name=$class->name_re;
  return qr{(?:$name)?(?:->|::|\.)$name}x;
};

sub line_re   {qr{.+}};
sub blank_re  {qr{[[:space:]]+$}};
sub nblank_re {qr{[^[:blank:]]+}};

sub shcmd_re  {Arstd::Re::posix_delim('`')};
sub char_re   {Arstd::Re::posix_delim("'")};
sub string_re {Arstd::Re::posix_delim('"')};
sub sigils_re {qr{\\?[\$@%&]}};

sub dev0_re   {
  return Arstd::Re::eiths(
    [qw(TODO NOTE)],
    bwrap=>1
  );
};

sub dev1_re   {
  return Arstd::Re::eiths(
    [qw(FIX BUG)],
    bwrap=>1
  );
};

sub DEFAULT {return {
  name        => null,

  com         => q[#],
  lcom        => q[#],

  hed         => 'N/A',
  ext         => null,
  mag         => null,

  highlight   => [],
  highlightup => [],

  type        => [],
  specifier   => [],

  builtin     => [],
  intrinsic   => [],
  fctl        => [],

  directive   => [],
  resname     => [],

  preproc     => no_match,
  use_sigils  => {},
}};


# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {
  return new_impl($class,$class->classattr());
};

sub new_impl($class,$O) {
  # make ice
  St::defnit($class,$O);
  my $self=bless $O,$class;

  # for replacing $:tag;> with
  # value of self->tag
  $self->{repl}=Arstd::Repl->new(
    pre  => 'PESC',
    inre => $class->pesc_re,
    repv => sub {repv($self,@_)},
  );

  # ^right here
  $self->make_keyw_re();

  # comments...
  $self->{lcom}=Arstd::Re::eaf(
    $self->{lcom},
    lbeg    => 0,
    opscape => 0,

  ) if $self->{lcom};


  # notify super and give
  $class->register($self);
  delete $self->{repl};
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
      $self->{repl}->proc($ARG);
      $out->{$ARG}=0;

    } @ar;

    # ^make composite
    my $keyw_re=(int %$out)
      ? Arstd::Re::eiths([keys %$out],bwrap=>1)
      : no_match
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

  throw "Bad key in peso escape: '$key'"
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
