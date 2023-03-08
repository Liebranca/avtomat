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

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Array;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    descape
    linewrap
    pretty_tag

    sqwrap
    dqwrap

    begswith
    charcon
    nobs

    strip

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.4;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $STRIP_RE=>qr{^\s*|\s*$}x;
  Readonly our $ESCAPE_RE=>qr"\x1B\[[\?\d;]+[\w]"x;
  Readonly our $NOBS_RE=>qr{\\(.)}x;

  Readonly my $LINEWRAP_PROTO=>q{(

    [^\n]{1,SZ_X} ((\n|\s)|$)
  | [^\n]{1,SZ_X} (.|$)

  )};

  Readonly our $CHARCON_DEF=>[

    qr{\\n}x   => "\n",
    qr{\\r}x   => "\r",
    qr{\\b}x   => "\b",

    qr{\\}x    => '\\',

  ];

# ---   *   ---   *   ---
# global state

# ---   *   ---   *   ---
# give back copy of string without ANSI escapes

sub descape($s) {

  $s=~ s{$ESCAPE_RE}{}sxgm;
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

  state $last_re=undef;
  state $last_sz=undef;

  # defaults
  $opt{add_newlines}//=1;

  my $re=(defined $last_re && $sz_x==$last_sz)
    ? $last_re
    : __make_linewrap_re($sz_x)
    ;

  $last_re=$re;
  $last_sz=$sz_x;

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
# string has prefix

sub begswith($s,$prefix) {
  return (rindex $s,$prefix,0)==0;

};

# ---   *   ---   *   ---
# convert match of seq into char

sub charcon($sref,$table=undef) {

  $table//=$CHARCON_DEF;

  my @pats=Arstd::Array::nkeys($table);
  my @seqs=Arstd::Array::nvalues($table);

  while(@pats && @seqs) {

    my $pat=shift @pats;
    my $seq=shift @seqs;

    $$sref=~ s[$pat][$seq]sxmg;

  };

  return;

};

# ---   *   ---   *   ---
# hides the backslash in \[char]

sub nobs($sref) {

  $$sref=~ s[$NOBS_RE][$1]sxmg;

};

# ---   *   ---   *   ---
# remove outer whitespace

sub strip($sref) {
  $$sref=~ s[$STRIP_RE][]sxmg;

};

# ---   *   ---   *   ---
1; # ret
