#!/usr/bin/perl
# ---   *   ---   *   ---
# DEPS CHECK
# of course you have to execute
# the file to know its dependencies!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Chk::Deps;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Arstd::throw;
  use parent 'Chk::Syntax';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# stores includes

sub incstk {
  state $out=[];
  return $out;
};


# ---   *   ---   *   ---
# _almost_ the same as Chk::Syntax::run
#
# only difference is this one
# will *never* throw ;>

sub run {
  my $class=shift; # drop class

  my ($errme,$psig)=$class->begcapt();
  my @dep=$class->perlc($_[1]);

  $class->endcapt($psig);
  return ($_[0],@dep);
};


# ---   *   ---   *   ---
# clears out includes

sub begcapt {
  shift; # drop class

  my $stk=incstk();
  push @$stk,[{%INC},[@INC]];
  %INC=();
  @INC=();

  return Chk::Syntax->begcapt(@_);
};


# ---   *   ---   *   ---
# execs the code to get includes

sub perlc {
  shift; # drop class

  Chk::Syntax->perlc(@_);
  return grep {! ($ARG=~ qr{/perl5/})} values %INC;
};


# ---   *   ---   *   ---
# undoes begcapt, restoring the previous
# includes

sub endcapt {
  shift; # drop class

  my $stk  = incstk();
  my $prev = pop @$stk;

  %INC=%{$prev->[0]};
  @INC=@{$prev->[1]};

  return Chk::Syntax->endcapt(@_);
};


# ---   *   ---   *   ---
1; # ret
