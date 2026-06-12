#!/usr/bin/perl
# ---   *   ---   *   ---
# FTYPE
# Stuff assoc'd to extensions
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Chk qw(is_file is_blessref);
  use Arstd::Path qw(extof);
  use Arstd::strtok;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# GBL

  my $Cache={SUPER=>{}};
  sub cache {return $Cache};

# ---   *   ---   *   ---
# definition

sub classattr {return {name=>'SUPER'}};


# ---   *   ---   *   ---
# make ice

sub import {
  my ($class)=@_;
  my $have=$class->selfet();
  return (! defined $have)
    ? $class->new()
    : $have
    ;
};


# ---   *   ---   *   ---
# ^add entry

sub register($class,$ice) {
  no strict 'refs';
  my $subclass=($class eq __PACKAGE__)
    ? "$class\::$ice->{name}"
    : $class
    ;
  return if exists $Cache->{$subclass};

  # yes
  $Cache->{$subclass}    = $ice;
  $Cache->{$ice->{name}} = $ice;
  *$subclass=sub {return $Cache->{$subclass}};

  use strict 'refs';
  return;
};


# ---   *   ---   *   ---
# ^fetch

sub fet($class,$name) {
  return $Cache->{$name};
};
sub selfet($class) {
  return $class->fet(
    $class->classattr()->{name}
  );
};


# ---   *   ---   *   ---
# get ftype ice from filename

sub from_ext($file) {
  my $ext=extof($file);
  return undef if! $ext;

  for(values %$Cache) {
    next if! %$ARG;
    return $ARG if ".$ext"=~ qr{$ARG->{ext}};
  };
  return undef;
};


# ---   *   ---   *   ---
# ^ get syntax rules, if any are
#   defined by the filetype
#
# else uses default ones
# (defined by strtok)

sub syxof($file) {
  my $ftype = from_ext($file);
  my $def   = Arstd::strtok::defsyx();

  return $def if! $ftype
              ||! $ftype->can('strtok_syx');

  return $ftype->strtok_syx();
};


# ---   *   ---   *   ---
# placeholders for special pproc clauses...

sub package_open {
  my ($class,$name)=@_;
  return ();
};
sub package_close {
  my ($class,$dst,$sref,$name,$flg)=@_;
  return ();
};


# ---   *   ---   *   ---
# get rules for the tokenizer

sub getlang {
  # set defaults
  my ($lang,%O)=@_;
  $O{com}   //= 1;
  $O{pproc} //= 1;

  # get definitions from extension or
  # default to C syntax!!
  if(is_file($lang)) {
    $lang=from_ext($lang) // "Mny";
  };
  # fetch package containing defs
  if(! is_blessref($lang)) {
    $lang="Ftype\::Text\::$lang"
    if! ($lang=~ qr{^Ftype::Text::});
    AR::load($lang);

    $lang=$lang->selfet();
  };
  # ^make copy of syntax rules
  my $syx=[@{$lang->strtok_syx()}];

  # ^modify rules to conserve comments...
  if($O{com}) {
    $ARG->{keep}=1
    for grep {$ARG->{type} eq 'com'} @$syx;
  };
  # ^ and strip preprocessor lines, just
  #   to make them easier to read!
  if($O{pproc}) {
    $ARG->{strip}=1
    for grep {$ARG->{type} eq 'pproc'} @$syx;
  };
  return ($lang,$syx);
};


# ---   *   ---   *   ---
1; # ret
