#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD STRING
# Quick utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd::String;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    descape
    linewrap
    pretty_tag

    sqwrap
    dqwrap

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $ESCAPE_RE=qr"\x1B"x;

  my $LINEWRAP_PROTO=q{(

    [^\n]{1,SZ_X} (?: (\n|\s)|$)
  | [^\n]{1,SZ_X} (?: .|$)

  )};

# ---   *   ---   *   ---
# global state

# ---   *   ---   *   ---
# give back copy of string without ANSI escapes

sub descape($s) {

  $s=~ s/$ESCAPE_RE[\d;]+[\w\?]//;
  return $s;

};

# ---   *   ---   *   ---
# wrap string in quotes

sub sqwrap($s) {return "'$s'"};
sub dqwrap($s) {return "\"$s\""};

# ---   *   ---   *   ---
# builds regex for linewrapping

sub __make_linewrap_re($sz_x) {

  state $SZ_X_RE=qr{SZ_X}x;

  my $re=$LINEWRAP_PROTO;$sz_x--;
  $re=~ s[$SZ_X_RE][$sz_x]x;$sz_x--;
  $re=~ s[$SZ_X_RE][$sz_x]x;

  return $re;

};

# ---   *   ---   *   ---
# split string at X characters

sub linewrap($sref,$sz_x,%opt) {

  # defaults
  $opt{add_newlines}//=1;

  my $re=__make_linewrap_re($sz_x);

  if($opt{add_newlines}) {
    $$sref=~ s/($re)/$1\n/gsx;

  } else {
    $$sref=~ s/($re)/$1/gsx;

  };

};

# ---   *   ---   *   ---
# wraps word in tags with cute colors

sub pretty_tag($s) {

  return sprintf

    "\e[37;1m<\e[0m".
    "\e[34;22m%s\e[0m".
    "\e[37;1m>\e[0m",

    $s

  ;

};

# ---   *   ---   *   ---
1; # ret
