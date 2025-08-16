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
  use Chk qw(is_null);

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

  use lib "$ENV{ARPATH}/lib/";
  use AR ();
  use CMAM::static qw(
    cmamdef
    cpackage
    cmamout
    cmamout_push_pm
    cmamout_push_c
  );
  use CMAM::token qw(
    tokensplit
    tokenshift
    tokenpop
    tokentidy
    semipop
  );
  use CMAM::macro qw(
    macroguard
    macroload
    macrosave
    macroin
    macrofoot
  );


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
  # unpack && validate input
  $_[0]=macroguard([qw(expr)],@_);
  my ($expr)=macroin($_[0],qw(expr));

  # get package name
  my $name=tokenshift($expr);
  my @dstk=();

  # have language filter?
  if($name=~ qr{(?:pm|c)}i) {
    @dstk=(lc $name);
    $name=tokenshift($expr);

  # ^nope, use both ;>
  } else {
    @dstk=qw(pm c);
  };


  # need to perform perl package imports?
  if(int grep {$ARG eq 'pm'} @dstk) {
    # add perl dependency and load it into
    # the sandbox namespace
    my @req=cmamout_push_pm($name,$expr);
    AR::cloadi($name=>@req);
  };

  # need to append required C header?
  cmamout_push_c($name)
  if int grep {$ARG eq 'c'} @dstk;


  # cleanup and give
  $expr=null;
  macrofoot($_[0],qw(expr));
  return null;
};


# ---   *   ---   *   ---
1; # ret
