#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD ANSI
# For when you gotta ESCAPE
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::ansi;
  use v5.42.0;
  use strict;
  use warnings;

  use Term::ReadKey qw(GetTerminalSize);
  use List::Util qw(sum);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Style::null

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub escape_re {qr"\x{1B}\[[\?\d;]+[\w]"};


# ---   *   ---   *   ---
# get terminal size in chars

sub ttysz {
  my ($x,$y)=GetTerminalSize();
  return ($x,$y);

};


# ---   *   ---   *   ---
# wrap string in ansi color escapes

sub m($s,$id=off) {
  my $tab=>{
    op     => "\e[37;1m",
    num    => "\e[33;22m",
    warn   => "\e[33;1m",
    good   => "\e[34;22m",
    err    => "\e[31;22m",
    ctl    => "\e[35;1m",
    update => "\e[32;1m",
    ex     => "\e[36;1m",
    off    => "\e[0m",

  },

  my $color=(exists $tab->{$id})
    ? $tab->{$id}
    : $tab->{off}
    ;

  return "$color$s";

};


# ---   *   ---   *   ---
# wraps word in <braces> with colors

sub mtag($s,$id=0) {
  my $beg   = m('<','op');
  my $end   = m('>','op');
  my $color = m($s,$id);

  return "$beg$color$end";

};


# ---   *   ---   *   ---
# give back copy of string without ANSI escapes

sub descape($s) {
  my $re=escape_re;
  $s=~ s[$re][]sxgm;

  return $s;

};


# ---   *   ---   *   ---
# ^get [escape=>position]

sub popscape($sref) {
  my $re  = escape_re;
  my @out = ();
  while($$sref=~ s[($re)][]) {
    push @out,[$1,$-[0]];

  };

  return @out;

};


# ---   *   ---   *   ---
# ^undo

sub pushscape($sref,@ar) {
  my $out   = null;
  my $accum = 0;
  for(@ar) {
    my ($escape,$pos)=@$ARG;
    my $head=substr $$sref,$accum,$pos-$accum;

    $out   .= "$head$escape";
    $accum  = $accum+(length $head);

  };

  # overwrite
  $$sref=$out . (substr
    $$sref,
    $accum,
    length $$sref

  );

  return;

};


# ---   *   ---   *   ---
# ^get length of ANSI escapes in str

sub lenscape($s) {
  my @ar=split escape_re,$s;
  return sum(map {length $ARG} @ar);

};


# ---   *   ---   *   ---
1; # ret
