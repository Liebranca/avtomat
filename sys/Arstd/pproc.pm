#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD PPROC
# kinda like the C preprocessor
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::pproc;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);

  use Arstd::strtok;
  use Arstd::peso qw(peval);

  use Shb7::Find qw(ffind);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(pproc);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# we use this to record state across
# all subroutines

sub pproc_mem {
  state $mem={
    inc   => {},
    depth => 0,
  };
  return $mem;
};


# ---   *   ---   *   ---
# entry point
#
# [0]: byte pptr ; array to save token contents to
# [1]: byte ptr  ; string to process
# [2]: byte pptr ; options
#
# [!]: overwrites input string

sub pproc {
  my $strar = shift;
  my $sref  = \$_[0];
  shift;

  my %O=@_;

  $O{syx} //= Arstd::strtok::defsyx();

  # up the recursion depth
  ++pproc_mem()->{depth};

  # we're only interested in preprocessor
  # lines, so fetch the indices of those
  for my $i(Arstd::strtok::fet($$sref,'pproc')) {
    # make copy of value and untokenize it
    my $cpy=$strar->[$i];
    unstrok($cpy,$strar);

    # fetch and run command
    my ($cmd,@args)=Arstd::peso::getcmd($cpy);
    symtab($cmd)->($i,$strar,@args);
  };

  # go down one recursion level
  --pproc_mem()->{depth};
  return;
};


# ---   *   ---   *   ---
# opens file,
# recurses to process it,
# and then pastes it on original

sub pproc_fpaste {
  # either finds the file or throws
  my ($i,$dst,$fpath)=@_;
  $fpath=ffind(peval($fpath));

  # ^nothing if file already included ;>
  return if exists pproc_mem()->{inc}->{$fpath};
  pproc_mem()->{inc}->{$fpath}=1;


  # get syntax rules for this file
  my $syx=[@{Ftype::syxof($fpath)}];

  # ^ strip preprocessor lines within it,
  #   as stddpproc expects this to be the case
  $ARG->{strip}=1
  for grep {$ARG->{type} eq 'pproc'} @$syx;

  # now read and tokenize the file
  my $strar = [];
  my $body  = orc($body);
  strtok($strar,$body,syx=>$syx);

  # ^recurse and untokenize
  pproc($strar,$body,syx=>$syx);
  unstrtok($body,$strar);

  # overwrite preprocessor directive
  # with the body of the file
  $dst->[$i]=$body;

  return;
};


# ---   *   ---   *   ---
# function table

sub symtab {
  return {
    include=>\&pproc_fpaste,

  }->{$_[0]}

  or throw "pproc: undefined function '$_[0]'";
};


# ---   *   ---   *   ---
1; # ret
