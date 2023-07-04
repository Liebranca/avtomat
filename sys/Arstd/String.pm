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
  use Chk;

  use Arstd::Array;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    descape

    linewrap
    lineident

    ansim
    strtag

    sqwrap
    dqwrap

    begswith
    charcon
    nobs

    strip
    vstr

    deref_clist

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.5;#b
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

  Readonly our $COLOR=>{

    op     => "\e[37;1m",

    good   => "\e[34;22m",
    err    => "\e[31;22m",

    ctl    => "\e[35;1m",
    update => "\e[32;1m",
    ex     => "\e[36;1m",

  };

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
# ^adds ws padding on a
# per-line basis

sub lineident($sref,$x) {

  my $pad="\n" . (q[  ] x $x);

  $$sref=~ s[$NEWLINE_RE][$pad]sxmg;
  $$sref=(q[  ] x $x) . "$$sref";

};

# ---   *   ---   *   ---
# wrap string in ansi color escapes

sub ansim($s,$id) {

  my $color=(defined $COLOR->{$id})
    ? $COLOR->{$id}
    : "\e[30;1m"
    ;

  return "$color$s\e[0m";

};

# ---   *   ---   *   ---
# wraps word in <braces> with colors

sub strtag($s,$err=0) {

  return

    ansim('<','op')
  . ansim($s,($err) ? 'err' : 'good')

  . ansim('>','op')

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
# force vstr to v0.00.0 format

sub vstr($in) {

  my $v=(sprintf 'v%vd',$in);
  my @v=split m[\.],$v;

  $v[1]='0'.$v[1] if length $v[1]==1;
  $v=join q[.],@v;

  return $v;

};

# ---   *   ---   *   ---
# gets array from arrayref
# or comma-separated string

sub deref_clist($list) {

  return (is_arrayref($list))
    ? @$list
    : (split $COMMA_RE,$list)
    ;

};

# ---   *   ---   *   ---
1; # ret
