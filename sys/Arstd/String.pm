#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD STRING
# NULL-TERMINATED
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# info

package Arstd::String;
  use v5.42.0;
  use strict;
  use warnings;
  use Carp qw(croak);
  use English qw($ARG $MATCH);

  our $VERSION = 'v0.01.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# deps

AR sys {
  use Style (null);
  use Chk (is_arrayref is_null);
  lis Arstd::Array (nkeys);

};

use parent 'St';


# ---   *   ---   *   ---
# ROM

my $PKG=__PACKAGE__;
St::vconst {
  BIN_DIGITS => qr{[\:\.0-1]},
  OCT_DIGITS => qr{[\:\.0-7]},
  DEC_DIGITS => qr{[\:\.0-9]},
  HEX_DIGITS => qr{[\:\.0-9A-F]},

  HEXNUM_RE => sub {
    my $digits=$_[0]->HEX_DIGITS;
    return qr{(?:
      (?:(?:(?:\b0x)|\$)($digits+)(?:[L]?))
    | (?:($digits+)(?:h))

    )\b}x;

  },

  DECNUM_RE => sub {
    my $digits=$_[0]->DEC_DIGITS;
    return qr{\b(?:(?:[v]?)($digits+)(?:[f]?))\b}x;

  },

  OCTNUM_RE => sub {
    my $digits=$_[0]->OCT_DIGITS;
    return qr{\b(?:
      (?:(?:\\)($digits+))
    | (?:($digits+)(?:o))

    )\b}x;

  },

  BINNUM_RE => sub {
    my $digits=$_[0]->BIN_DIGITS;
    return qr{\b(?:
      (?:(?:0b)($digits+))
    | (?:($digits+)(?:b))

    )\b}x;

  },

};


# ---   *   ---   *   ---
# join null,(list)

sub cat {join null,@_};


# ---   *   ---   *   ---
# ^split null,string

sub chars {split null,$_[0]};


# ---   *   ---   *   ---
# common string to integer transforms

sub stoi($x,$base,$filter=1) {
  state $tab={

    2  => {
      allow => $PKG->BIN_DIGITS,
      mul   => 1,

    },

    8  => {
      allow => $PKG->OCT_DIGITS,
      mul   => 3,

    },

    16 => {
      allow => $PKG->HEX_DIGITS,
      mul   => 4,

    },

  };


  # ^get ctx
  my $mode=$tab->{$base}
  or croak "Invalid base for stoi: '$base'";

  my $allow = $mode->{allow};
  my $mul   = $mode->{mul};

  # ^get negative
  my $sign=1;
  if(begswith($x,'-')) {
    $x    = substr $x,1,(length $x)-1;
    $sign = -1;

  };

  # filter invalid chars accto base?
  my @chars=reverse chars $x;

  if($filter) {
    @chars=grep {$ARG=~ $allow} @chars;

  # ^nope, give undef if invalid chars
  # ^found in source
  } else {
    my @tmp=grep {$ARG=~ $allow} @chars;
    return undef if int @tmp < int @chars;

    @chars=@tmp;

  };


  # accumulate to
  my $r=0;
  my $i=0;

  # walk chars in str
  map {

    # fraction part
    if($ARG=~ qr{\.}) {

      my $bit = 1 << ($i * $mul);

      $r *= 1/$bit;
      $i  = 0;

    # ':' separator ignored
    } elsif($ARG=~ qr{:}) {

    # ^integer part
    } else {

      my $v=ord($ARG);

      $v -= ($v > 0x39) ? 55 : 0x30;
      $r += $v << ($i * $mul);

      $i++;

    };

  } @chars;


  return $r*$sign;

};


# ---   *   ---   *   ---
# ^sugar

sub hstoi($x) {stoi($x,16)};
sub ostoi($x) {stoi($x,8)};
sub bstoi($x) {stoi($x,2)};


# ---   *   ---   *   ---
# ^infer base from string

sub sstoi($s,$filter=1) {
  my $tab={
    ($PKG->HEXNUM_RE) => 16,
    ($PKG->OCTNUM_RE) => 8,
    ($PKG->BINNUM_RE) => 2,

  };

  my ($key)=grep {$s=~ m[^$ARG$]} keys %$tab;

  # give conversion if valid
  if(defined $key) {
    $s=~ s[$key][$1]sxmg;
    return stoi($s,$tab->{$key},$filter);

  };

  # else give back input if it's a number!
  return ($s=~ qr{^[\d\.]+$})
    ? $s
    : undef
    ;

};


# ---   *   ---   *   ---
# wrap string in quotes

sub sqwrap($s) {return "'$s'"};
sub dqwrap($s) {return "\"$s\""};


# ---   *   ---   *   ---
# builds regex for linewrapping

sub linewrap_re($sz) {
  my $re=cat(
    '(?<mess>',
    '[^\n]{1,' . ($sz-1) . '}',
    '(?: (?: \n|\s) | $)',
    '|',
    '[^\n]{1,' . ($sz-2) . '}',
    '(?: .|$)'

  );

  return qr{$re};

};


# ---   *   ---   *   ---
# split string at X characters

sub linewrap($sref,$sz) {
  my $re=linewrap_re($sz);
  return map {
    chomp $ARG;
    $ARG;

  } resplit($sref,$re);

};


# ---   *   ---   *   ---
# ^adds ws padding on a
# ^per-line basis

sub ilinewrap($sref,$padsz,$linesz) {
  my $pad='  ' x $padsz;
  return map {"$pad$ARG"} linewrap($sref,$linesz);

};


# ---   *   ---   *   ---
# split string with a capturing regex,
# then filter out result

sub resplit {
  return gstrip(split $_[1],$_[0]);

};


# ---   *   ---   *   ---
# captures matches for a subst re

sub recapts {
  my    @out;
  push  @out,$MATCH
  while $_[0]=~ s[$_[1]][]sxm;

  return @out;

};


# ---   *   ---   *   ---
# string has prefix

sub begswith {
  return 0 == rindex $_[0],$_[1],0;

};


# ---   *   ---   *   ---
# convert match of seq into char

sub charcon {
  return 0 if is_null $_[0];

  # set default
  $_[1]//=[
    qr{\\n} => "\n",
    qr{\\r} => "\r",
    qr{\\b} => "\b",
    qr{\\}  => '\\',
    qr{\\e} => "\e",

  ];

  # ^replace
  for(0..int(@{$_[1]}/2)-1) {
    my $pat=$_[1]->[$ARG*2+0];
    my $seq=$_[1]->[$ARG*2+1];

    $_[0]=~ s[$pat][$seq]sxmg;

  };

  return ! is_null $_[0];

};


# ---   *   ---   *   ---
# hides the backslash in \[char]

sub nobs {
  return 0 if is_null $_[0];
  my $re=qr{\\(.)}x;

  $_[0]=~ s[$re][$1]sxmg;
  return ! is_null $_[0];

};


# ---   *   ---   *   ---
# remove outer whitespace

sub strip {
  return 0 if is_null $_[0];
  my $re=qr{(?:^\s*)|(?:\s*$)};

  $_[0]=~ s[$re][]smg;
  return ! is_null $_[0];

};


# ---   *   ---   *   ---
# ^from array, filters out empty

sub gstrip {
  return grep {strip $ARG} @_;

};


# ---   *   ---   *   ---
# gets array from arrayref
# or comma-separated string

sub deref_clist($value) {
  return (is_arrayref $value)
    ? (@$value)
    : (split qr{,},$value)
    ;

};


# ---   *   ---   *   ---
# join grepped

sub joinfilt {
  my $s=shift;
  return join $s,gstrip @_;

};


# ---   *   ---   *   ---
# ^cats string to first elem

sub prepend($s,@args) {
  return (@args)
    ? $s . joinfilt($s,@args)
    : null
    ;

};


# ---   *   ---   *   ---
1; # ret

