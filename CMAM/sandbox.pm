#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM SANDBOX
# come out to play
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package CMAM::sandbox;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_hashref);

  use Arstd::String qw(
    strip
    gstrip
    gsplit
  );
  use Arstd::Path qw(
    from_pkg
    extwap
  );
  use Arstd::throw;
  use Arstd::Token qw(
    tokensplit
    tokenshift
    tokenpop
    tokentidy
    semipop
  );
  use Tree::C;

  use lib "$ENV{ARPATH}/lib/";
  use AR ();
  use CMAM::static qw(
    cmamdef
    cpackage
    cmamfn
    cmamout
    cmamout_push_pm
    cmamout_push_c
    ctree
  );
  use CMAM::macro qw(
    macroload
    macrosave
    c_to_perl
    parse_as_label
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(strnd clnd fnnd);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# performs depschk for file
#
# [*]: writes to CMAMOUT

sub usepkg {
  my ($nd)=@_;

  # first convert the node into a string
  $nd->{cmd}="";
  my $expr=c_to_perl($nd);
  ctree()->unstrtok($expr);

  $nd->{expr}=$expr;

  # get package name
  my $name=tokenshift($nd);

  # have language filter?
  my ($c,$pm)=(1,1);
  if($name=~ qr{\b(pm|c)\b}i) {
    my $have=lc $name;
    ($c,$pm)=($have eq 'c',$have eq 'pm');
    $name=tokenshift($nd);
  };

  # sneaky shorthand
  if($name eq 'cmam') {
    $name = "SWAN::cmacro";
    $expr = "qw(" . join(' ',qw(
      PKGINFO VERSION AUTHOR
      public typename deref sign
      typedef fwraps
    )) . ');';

    $c  = 0;
    $pm = 1;
  };

  # need to perform perl package imports?
  if($pm) {
    # add perl dependency and load it into
    # the sandbox namespace
    my @req=cmamout_push_pm($name,$expr);
    AR::reload($name=>@req);
  };

  # need to append required C header?
  my @out=();
  if($c) {
    push @out,strnd(cmamout_push_c($name));
  };

  # give C import if any
  %$nd=();
  return @out;
};


# ---   *   ---   *   ---
# make new expression node from string

sub strnd {return ctree()->rd($_[0])->to_expr()};


# ---   *   ---   *   ---
# clear expression

sub clnd {%{$_[0]}=();return};


# ---   *   ---   *   ---
# get a function hashref from a node

sub fnnd($nd) {
  # convert to node if string passed
  $nd=strnd($nd) if ! is_hashref($nd);

  # catch invalid input
  throw "Not a valid function decl:\n"
  .     ctree()->expr_to_code($nd)

  .     "\n\nCannot make function."

  if $nd->{type} ne 'proc';

  # _now_ perform conversion
  my $fn=Tree::C::node_to_fn($nd);

  # drop specifier?
  my $type=null;
  if($nd->{cmd}=~ Tree::C::spec_re()) {
    $type      = "$nd->{cmd} $fn->{type}";
    $nd->{cmd} = tokenshift($nd);

  } else {
    $type="$fn->{type}";
  };

  # '$type' here is the return type of the
  # function you passed, *plus* specifiers
  #
  # '$fn->{type}' is that return type
  # *without* the specifiers
  #
  # this is just so you can wrap/mutate functions
  # without inheriting specs like inline, public,
  # static, and so on
  return ($fn,$type);
};


# ---   *   ---   *   ---
1; # ret
