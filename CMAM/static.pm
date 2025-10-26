#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM STATIC
# guts
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package CMAM::static;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);

  use Arstd::String qw(gsplit);
  use Arstd::Path qw(from_pkg extwap);

  use lib "$ENV{ARPATH}/lib/";
  use AR ();

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    cpackage
    cmamlol
    cmamgbl
    cmamdef

    is_local_scope
    set_local_scope
    unset_local_scope

    cmamout
    cmamout_push_pm
    cmamout_push_c
    cmamout_exported
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# RAM

  my $CMAMDEF={};
  my $CMAMOUT={};
  my $CSCOPE;
  my $CPACKAGE;
  my $CFLAG;


# ---   *   ---   *   ---
# get current package from C space
#
# [<]: mem ptr ; selfex

sub cpackage {
  $CPACKAGE=$_[0] if ! is_null($_[0]);
  return (! is_null($CPACKAGE))
  ? $CPACKAGE
  : 'cmacro'
  ;
};


# ---   *   ---   *   ---
# get handle to output buffer
#
# [<]: mem ptr ; output hashref

sub cmamout {
  my $pkg=cpackage();
  $CMAMOUT->{$pkg}//={
    def    => [],
    dep    => {c=>[],pm=>[]},
    type   => [],
    export => [],
  };
  return $CMAMOUT->{$pkg};
};


# ---   *   ---   *   ---
# get local/global scope

sub cmamlol {return $CSCOPE->{local}};
sub cmamgbl {return $CSCOPE->{global}};


# ---   *   ---   *   ---
# get defined symbols

sub cmamdef {return $CMAMDEF};


# ---   *   ---   *   ---
# wipes global state
#
# use this when you start processing
# a new file

sub restart {
  # unimport any packages that were dynamically
  # loaded while processing the previous file
  for(@{cmamout()->{dep}->{pm}}) {
    AR::unload($ARG->[0]);
  };

  # ^current package last ;>
  my $pkg=cpackage();
  AR::unload(cpackage());


  # delete any dynamically defined symbols
  #
  # we do this to make sure a file cannot
  # access things it hasn't directly or
  # indirectly included

  no strict 'refs';
  for(grep {
    ! ($ARG=~ qr{(?:package|use|macro)})

  } keys %$CMAMDEF) {
    *{"CMAM\::sandbox\::$ARG"}=undef;
    delete $CMAMDEF->{$ARG};
  };
  use strict 'refs';

  # now reset globals
  $CMAMDEF  = {};
  $CMAMOUT  = {};
  $CSCOPE   = {local=>{},global=>{}};
  $CPACKAGE = null;
  $CFLAG    = 0x00;

  return;
};


# ---   *   ---   *   ---
# get/set global flags

sub is_local_scope    {$CFLAG &   0x01};
sub set_local_scope   {$CFLAG |=  0x01};
sub unset_local_scope {$CFLAG &=~ 0x01};


# ---   *   ---   *   ---
# add perl dependency
#
# [0]: byte ptr ; package name
# [1]: byte ptr ; import arguments
#
# [<]: byte pptr ; import argument (as new array)
#
# [*]: writes to output hash

sub cmamout_push_pm {
  # get args passed to import;
  my $qw_re  = qr{qw\s*\(([^\)]+)\)\s*;};
  my ($have) = ($_[1]=~ $qw_re);
  my @req    = gsplit($have);

  # append to out and give required symbols
  push @{cmamout()->{dep}->{pm}},[$_[0]=>@req];
  return @req;
};


# ---   *   ---   *   ---
# add C dependency
#
# [0]: byte ptr ; package name
# [*]: writes to output hash

sub cmamout_push_c {
  my $cpy="$_[0]";
  from_pkg($cpy);
  extwap($cpy,'h');
  push @{cmamout()->{dep}->{c}},$cpy;

  return;
};


# ---   *   ---   *   ---
1; # ret
